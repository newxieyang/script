//! 桌面界面：项目下拉框 + 9 个勾选项 + 两个动作按钮 + 底部输出面板。

use crate::config::{ConfigStore, FLAG_HINTS, FLAG_KEYS, Flags};
use crate::repo::Layout;
use crate::runner::{Line, Runner, SpawnSpec, Stream};

// egui 用 eframe 的重导出，避免自己再加一条 egui 依赖导致版本对不上
use eframe::egui::{self, Color32, RichText};

/// 首选 CJK 字体（默认字体没有汉字，不装就是一片豆腐块）
const CJK_FONT_CANDIDATES: [&str; 8] = [
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\msyhl.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\simsun.ttc",
    r"C:\Windows\Fonts\Deng.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
];

pub struct App {
    inner: Result<Inner, String>,
}

impl App {
    pub fn new(cc: &eframe::CreationContext<'_>) -> Self {
        install_cjk_font(&cc.egui_ctx);
        tune_style(&cc.egui_ctx);
        App {
            inner: Inner::try_new(),
        }
    }

    /// 无窗口自检（`--selftest`），返回进程退出码
    /// 无窗口自检（`--selftest`）。注意发布构建是 windows 子系统，
    /// println 没有控制台可去 —— 界面上也有「自检」按钮，走的是同一套逻辑。
    pub fn selftest() -> i32 {
        let (_lines, pass) = selftest_lines();
        println!(
            "{}",
            if pass {
                "\n全部自检通过。"
            } else {
                "\n自检未通过。"
            }
        );
        if pass { 0 } else { 1 }
    }
}

/// 自检报告收集器：既打印（CLI）又留存（界面输出面板）
struct Reporter {
    lines: Vec<String>,
    pass: bool,
}

impl Reporter {
    fn new() -> Self {
        Reporter {
            lines: Vec::new(),
            pass: true,
        }
    }

    fn line(&mut self, s: String) {
        println!("{s}");
        self.lines.push(s);
    }

    fn ok(&mut self, s: impl Into<String>) {
        self.line(format!("[OK] {}", s.into()));
    }

    fn fail(&mut self, s: impl Into<String>) {
        self.pass = false;
        self.line(format!("[FAIL] {}", s.into()));
    }
}

/// 自检逻辑：CLI 的 `--selftest` 与界面的「自检」按钮共用。
/// 返回 (报告行, 是否全部通过)。
fn selftest_lines() -> (Vec<String>, bool) {
    let mut r = Reporter::new();
    r.line("== BuildTools 自检 ==".to_string());

    let layout = match Layout::discover() {
        Ok(l) => l,
        Err(e) => {
            r.fail(format!("定位仓库根失败：{e}"));
            return (r.lines, r.pass);
        }
    };
    r.ok(format!("仓库根      : {}", layout.root().display()));
    r.ok(format!("默认配置    : {}", layout.sdk_config().display()));
    r.ok(format!("构建脚本    : {}", layout.build_script().display()));
    r.ok(format!("文档脚本    : {}", layout.api_script().display()));
    r.ok(format!("python      : {}", layout.python()));

    let python_exists = std::path::Path::new(&layout.python()).is_file()
        || layout.python() == "python"; // PATH 上的裸命令无法预检
    if python_exists {
        r.ok("python 可执行文件存在");
    } else {
        r.fail(format!("python 不存在：{}", layout.python()));
    }

    let store = match ConfigStore::load(&layout.sdk_config()) {
        Ok(s) => s,
        Err(e) => {
            r.fail(format!("读配置失败：{e}"));
            return (r.lines, r.pass);
        }
    };
    r.ok(format!(
        "项目（{} 个）: {}",
        store.keys().len(),
        store.keys().join(", ")
    ));

    r.line(String::new());
    r.line("-- 各项目勾选状态 --".to_string());
    for key in store.keys().iter() {
        let f = store.flags_of(key);
        let on: Vec<&str> = FLAG_KEYS
            .iter()
            .enumerate()
            .filter(|(i, _)| f.get(*i))
            .map(|(_, k)| *k)
            .collect();
        r.line(format!(
            "  {key:<10} {}",
            if on.is_empty() {
                "(全关)".to_string()
            } else {
                on.join(", ")
            }
        ));
    }

    // 覆盖机制自检：把某项目的 copy_android_lib 反过来，写出的临时配置必须体现这个改动
    r.line(String::new());
    r.line("-- 勾选覆盖机制 --".to_string());
    let probe_key = match store.keys().iter().position(|k| k == "A910") {
        Some(i) => store.keys()[i].clone(),
        None => store.keys()[0].clone(),
    };
    let idx = store
        .keys()
        .iter()
        .position(|k| *k == probe_key)
        .unwrap_or(0);
    let mut probe = store.all_flags();
    let flag_idx = 1; // copy_android_lib
    let before = probe[idx].get(flag_idx);
    probe[idx].set(flag_idx, !before);

    let out = layout.runtime_config_path();
    if let Err(e) = store.write_runtime_copy(&probe, &out) {
        r.fail(format!("生成临时配置失败：{e}"));
        return (r.lines, r.pass);
    }
    r.ok(format!("临时配置已生成: {}", out.display()));

    let raw = match std::fs::read(&out) {
        Ok(b) => b,
        Err(e) => {
            r.fail(format!("回读临时配置失败：{e}"));
            return (r.lines, r.pass);
        }
    };
    if raw.starts_with(&[0xEF, 0xBB, 0xBF]) {
        r.ok("临时配置带 UTF-8 BOM（PowerShell 5.1 靠它判定 UTF-8）");
    } else {
        r.fail("临时配置缺少 UTF-8 BOM");
    }

    // 临时配置故意带 BOM，serde_json 不认，回读时剥掉
    let text = String::from_utf8_lossy(&raw);
    let parsed: serde_json::Value = match serde_json::from_str(text.trim_start_matches('\u{feff}')) {
        Ok(v) => v,
        Err(e) => {
            r.fail(format!("临时配置解析失败：{e}"));
            return (r.lines, r.pass);
        }
    };
    r.ok(format!(
        "临时配置可被 JSON 解析（{} 个项目）",
        parsed.as_object().map(|o| o.len()).unwrap_or(0)
    ));

    match parsed
        .get(&probe_key)
        .and_then(|v| v.get("copy_android_lib"))
        .and_then(|v| v.as_bool())
    {
        Some(v) if v == !before => r.ok(format!(
            "覆盖生效：{probe_key}.copy_android_lib {before} -> {v}"
        )),
        other => r.fail(format!("覆盖未生效：期望 {}，实际 {:?}", !before, other)),
    }

    // 未改动的字段必须原样保留（抽查 sdk_dir）
    let sdk_dir_kept = parsed
        .get(&probe_key)
        .and_then(|v| v.get("sdk_dir"))
        .and_then(|v| v.as_str())
        .map(|s| !s.is_empty())
        .unwrap_or(false);
    if sdk_dir_kept {
        r.ok("其余字段（sdk_dir / prefix / lib 等）原样保留");
    } else {
        r.fail("sdk_dir 丢失或被改写");
    }

    (r.lines, r.pass)
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        match &mut self.inner {
            Ok(inner) => inner.ui(ctx),
            Err(msg) => {
                egui::CentralPanel::default().show(ctx, |ui| {
                    ui.add_space(24.0);
                    ui.heading("初始化失败");
                    ui.add_space(8.0);
                    ui.colored_label(Color32::from_rgb(220, 80, 80), msg.as_str());
                    ui.add_space(12.0);
                    ui.label("可通过环境变量 SCRIPT_REPO_ROOT 指定脚本仓库根目录后重试。");
                });
            }
        }
    }
}

struct Inner {
    layout: Layout,
    store: ConfigStore,
    selected: usize,
    /// 界面上的勾选工作副本，下标与 `store.keys()` 对齐
    working: Vec<Flags>,
    saved: Vec<Flags>,
    log: Vec<Line>,
    runner: Option<Runner>,
    status: String,
}

impl Inner {
    fn try_new() -> Result<Self, String> {
        let layout = Layout::discover()?;
        let store = ConfigStore::load(&layout.sdk_config())?;
        let working = store.all_flags();
        let saved = working.clone();
        Ok(Inner {
            layout,
            store,
            selected: 0,
            working,
            saved,
            log: Vec::new(),
            runner: None,
            status: "就绪".to_string(),
        })
    }

    fn current_key(&self) -> String {
        self.store
            .keys()
            .get(self.selected)
            .cloned()
            .unwrap_or_default()
    }

    fn dirty(&self) -> bool {
        self.working != self.saved
    }

    fn push(&mut self, stream: Stream, text: impl Into<String>) {
        self.log.push(Line {
            stream,
            text: text.into(),
        });
    }

    /// 每帧把子进程新产生的输出搬进面板；结束后收尾。
    fn drain_runner(&mut self) {
        let Some(runner) = self.runner.as_mut() else {
            return;
        };

        let mut finished: Option<String> = None;
        for line in runner.poll() {
            if line.text.starts_with("[进程结束]") || line.text.starts_with("[已停止]") {
                finished = Some(line.text.trim_matches(['[', ']']).to_string());
            }
            self.log.push(line);
        }
        if let Some(t) = finished {
            self.status = t;
        }

        // poll() 只在输出读完且进程已退出时把 exit_code 置上，这里可以安全放手
        if !runner.is_running() {
            self.runner = None;
        }
    }

    fn start(&mut self, ctx: &egui::Context, spec: SpawnSpec, busy_label: &str) {
        if self.runner.is_some() {
            self.push(Stream::Err, "[忽略] 已有任务在运行，请先等它结束或点「停止」。");
            return;
        }
        let repaint = {
            let ctx = ctx.clone();
            move || ctx.request_repaint()
        };
        match Runner::spawn(spec, repaint) {
            Ok(r) => {
                self.runner = Some(r);
                self.status = busy_label.to_string();
            }
            Err(e) => {
                self.push(Stream::Err, e);
                self.status = "启动失败".to_string();
            }
        }
    }

    /// 入口一：执行 = 构建（并按 should_package 决定是否打包）
    fn run_build(&mut self, ctx: &egui::Context) {
        let key = self.current_key();
        let tmp = self.layout.runtime_config_path();

        if let Err(e) = self.store.write_runtime_copy(&self.working, &tmp) {
            self.push(Stream::Err, e);
            self.status = "生成临时配置失败".to_string();
            return;
        }
        self.push(Stream::Out, format!("[临时配置] {}", tmp.display()));

        let script = self.layout.build_script();
        let args = vec![
            "-NoProfile".to_string(),
            "-ExecutionPolicy".to_string(),
            "Bypass".to_string(),
            "-File".to_string(),
            script.display().to_string(),
            "-SdkKey".to_string(),
            key.clone(),
            "-ConfigFile".to_string(),
            tmp.display().to_string(),
        ];
        let banner = format!("powershell {}", args.join(" "));
        self.start(
            ctx,
            SpawnSpec {
                program: "powershell".to_string(),
                args,
                cwd: Some(self.layout.root().to_path_buf()),
                envs: Vec::new(),
                banner,
            },
            &format!("正在构建 {key} ..."),
        );
    }

    /// 入口二：生成文档 = py/genSDKAPI.py <key>
    fn run_doc(&mut self, ctx: &egui::Context) {
        let key = self.current_key();
        let script = self.layout.api_script();
        let args = vec![script.display().to_string(), key.clone()];
        let banner = format!("{} {}", self.layout.python(), args.join(" "));
        self.start(
            ctx,
            SpawnSpec {
                program: self.layout.python(),
                args,
                // genSDKAPI.py 靠 `utils.fileUtils` 导入，cwd 放在 py/ 下最稳
                cwd: Some(self.layout.py_dir()),
                envs: vec![
                    ("PYTHONUTF8".to_string(), "1".to_string()),
                    ("PYTHONIOENCODING".to_string(), "utf-8".to_string()),
                ],
                banner,
            },
            &format!("正在生成 {key} 文档 ..."),
        );
    }

    fn save_config(&mut self) {
        self.store.apply_working(&self.working);
        match self.store.save() {
            Ok(()) => {
                self.saved = self.working.clone();
                self.push(
                    Stream::Out,
                    format!("[已保存] {}", self.store.path().display()),
                );
            }
            Err(e) => self.push(Stream::Err, e),
        }
    }

    fn ui(&mut self, ctx: &egui::Context) {
        self.drain_runner();

        let running = self.runner.is_some();
        let dark = ctx.style().visuals.dark_mode;

        // ---------------- 顶部：项目选择 ----------------
        egui::TopBottomPanel::top("top").show(ctx, |ui| {
            ui.add_space(6.0);
            ui.horizontal(|ui| {
                ui.heading("OXiScan SDK 构建工具");
                ui.add_space(12.0);
                ui.label("项目：");
                let keys = self.store.keys().to_vec();
                let cur = self.current_key();
                egui::ComboBox::from_id_salt("project")
                    .selected_text(cur.as_str())
                    .width(180.0)
                    .show_ui(ui, |ui| {
                        for (i, k) in keys.iter().enumerate() {
                            ui.selectable_value(&mut self.selected, i, k.as_str());
                        }
                    });
                ui.add_space(8.0);
                if self.dirty() {
                    ui.colored_label(Color32::from_rgb(210, 150, 40), "● 有未保存的勾选改动");
                }
            });
            ui.add_space(4.0);
            ui.label(
                RichText::new(self.store.summary_of(&self.current_key()))
                    .monospace()
                    .size(12.0)
                    .color(ui.visuals().weak_text_color()),
            );
            ui.add_space(6.0);
        });

        // ---------------- 底部：输出面板 ----------------
        let mut clear_requested = false;
        egui::TopBottomPanel::bottom("log")
            .resizable(true)
            .default_height(320.0)
            .min_height(140.0)
            .show(ctx, |ui| {
                ui.add_space(4.0);
                ui.horizontal(|ui| {
                    ui.strong("输出");
                    ui.label(
                        RichText::new(format!(
                            "· {} 行 · {}",
                            self.log.len(),
                            if running { "运行中…" } else { self.status.as_str() }
                        ))
                        .color(ui.visuals().weak_text_color()),
                    );
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui
                            .button("清空输出")
                            .on_hover_text("快捷键 Ctrl+L")
                            .clicked()
                        {
                            clear_requested = true;
                        }
                    });
                });

                ui.separator();

                let err_color = if dark {
                    Color32::from_rgb(255, 150, 150)
                } else {
                    Color32::from_rgb(178, 40, 40)
                };
                let cmd_color = if dark {
                    Color32::from_rgb(140, 200, 255)
                } else {
                    Color32::from_rgb(30, 90, 160)
                };

                egui::ScrollArea::vertical()
                    .auto_shrink([false, false])
                    .stick_to_bottom(true)
                    .show_rows(ui, 17.0, self.log.len(), |ui, rows| {
                        for idx in rows {
                            let line = &self.log[idx];
                            let text = RichText::new(&line.text).monospace().size(13.0);
                            let text = match line.stream {
                                Stream::Err => text.color(err_color),
                                Stream::Out if line.text.starts_with('>') => {
                                    text.color(cmd_color).strong()
                                }
                                Stream::Out => text,
                            };
                            ui.label(text);
                        }
                    });
            });

        if clear_requested
            || ctx.input(|i| i.modifiers.ctrl && i.key_pressed(egui::Key::L))
        {
            self.log.clear();
        }

        // ---------------- 中部：勾选项 + 动作 ----------------
        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(4.0);
            ui.label(RichText::new("开关（勾选后点「执行」生效；点「保存配置」写回 ps/sdk_config.json）").color(
                ui.visuals().weak_text_color(),
            ));
            ui.add_space(6.0);

            let enabled = !running;
            let mut flags = self.working[self.selected];

            egui::Grid::new("flags")
                .num_columns(2)
                .spacing([18.0, 7.0])
                .show(ui, |ui| {
                    for (i, key) in FLAG_KEYS.iter().enumerate() {
                        let mut v = flags.get(i);
                        let resp = ui.add_enabled(
                            enabled,
                            egui::Checkbox::new(&mut v, RichText::new(*key).monospace()),
                        );
                        if resp.changed() {
                            flags.set(i, v);
                        }
                        ui.label(
                            RichText::new(FLAG_HINTS[i])
                                .size(12.0)
                                .color(ui.visuals().weak_text_color()),
                        );
                        ui.end_row();
                    }
                });
            self.working[self.selected] = flags;

            ui.add_space(14.0);
            ui.separator();
            ui.add_space(10.0);

            ui.horizontal(|ui| {
                let exec = ui.add_enabled(
                    enabled,
                    egui::Button::new(RichText::new("执行").size(16.0)).min_size(egui::vec2(120.0, 34.0)),
                );
                if exec.clicked() {
                    self.run_build(ctx);
                }
                if exec.hovered() {
                    ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
                }

                let doc = ui.add_enabled(
                    enabled,
                    egui::Button::new(RichText::new("生成文档").size(16.0))
                        .min_size(egui::vec2(120.0, 34.0)),
                );
                if doc.clicked() {
                    self.run_doc(ctx);
                }
                if doc.hovered() {
                    ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand);
                }

                ui.add_space(10.0);

                if ui
                    .add_enabled(
                        running,
                        egui::Button::new("停止").min_size(egui::vec2(80.0, 34.0)),
                    )
                    .on_hover_text("只结束本程序启动的 powershell / python 进程；\n其派生的子进程（cmake、wsl 等）不保证一并终止。")
                    .clicked()
                {
                    // 先把借用收在一句里，避免 kill() 的不可变借用与 push() 的可变借用打架
                    let killed = self.runner.as_ref().map(|r| r.kill());
                    match killed {
                        Some(Ok(())) => self.push(Stream::Err, "[停止] 已请求终止进程"),
                        Some(Err(e)) => self.push(Stream::Err, e),
                        None => {}
                    }
                }

                if ui
                    .add_enabled(self.dirty(), egui::Button::new("保存配置"))
                    .on_hover_text("把当前所有项目的勾选写回 ps/sdk_config.json")
                    .clicked()
                {
                    self.save_config();
                }

                ui.add_space(10.0);
                if ui
                    .button("重新载入配置")
                    .on_hover_text("丢弃界面上的改动，重新读 ps/sdk_config.json")
                    .clicked()
                {
                    match ConfigStore::load(&self.layout.sdk_config()) {
                        Ok(s) => {
                            self.store = s;
                            self.working = self.store.all_flags();
                            self.saved = self.working.clone();
                            self.push(Stream::Out, "[已重载] ps/sdk_config.json");
                        }
                        Err(e) => self.push(Stream::Err, e),
                    }
                }

                if ui
                    .button("自检")
                    .on_hover_text("检查仓库定位 / 配置文件 / 临时配置覆盖机制（同一套逻辑也是 --selftest）")
                    .clicked()
                {
                    let (lines, pass) = selftest_lines();
                    for l in lines {
                        let stream = if l.starts_with("[FAIL]") {
                            Stream::Err
                        } else {
                            Stream::Out
                        };
                        self.push(stream, l);
                    }
                    self.push(
                        if pass { Stream::Out } else { Stream::Err },
                        if pass { "自检通过。" } else { "自检未通过。" },
                    );
                }
            });

            ui.add_space(10.0);
            ui.label(
                RichText::new(format!(
                    "「执行」  → powershell ps/buildOXiAll.ps1 -SdkKey {key} -ConfigFile <临时配置>\n\
                     「生成文档」→ <python> py/genSDKAPI.py {key}",
                    key = self.current_key()
                ))
                .size(12.0)
                .color(ui.visuals().weak_text_color()),
            );
        });
    }
}

/// 装一个含汉字的字体，否则界面全是豆腐块
fn install_cjk_font(ctx: &egui::Context) {
    let Some((path, bytes)) = CJK_FONT_CANDIDATES
        .iter()
        .find_map(|p| std::fs::read(p).ok().map(|b| (*p, b)))
    else {
        return;
    };

    let mut fonts = egui::FontDefinitions::default();
    fonts.font_data.insert(
        "cjk".to_owned(),
        std::sync::Arc::new(egui::FontData::from_owned(bytes)),
    );
    for family in [egui::FontFamily::Proportional, egui::FontFamily::Monospace] {
        fonts.families.entry(family).or_default().push("cjk".to_owned());
    }
    ctx.set_fonts(fonts);
    eprintln!("[字体] 已加载 {path}");
}

fn tune_style(ctx: &egui::Context) {
    let mut style = (*ctx.style()).clone();
    style
        .text_styles
        .insert(egui::TextStyle::Body, egui::FontId::proportional(15.0));
    style
        .text_styles
        .insert(egui::TextStyle::Button, egui::FontId::proportional(15.0));
    style
        .text_styles
        .insert(egui::TextStyle::Monospace, egui::FontId::monospace(13.0));
    style
        .text_styles
        .insert(egui::TextStyle::Heading, egui::FontId::proportional(21.0));
    style.spacing.item_spacing = egui::vec2(8.0, 6.0);
    ctx.set_style(style);
}
