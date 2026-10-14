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

/// 各开关在界面上的主标签（与 FLAG_KEYS 一一对应，短说明在 config::FLAG_HINTS）
const FLAG_LABELS: [&str; 9] = [
    "Windows 库",
    "Android 库",
    "Linux 库",
    "保留最新文档",
    "静态库",
    "Android",
    "Windows",
    "Linux",
    "结束后自动打包",
];

/// 「复制进包」卡片里的开关下标
const COPY_IDX: [usize; 3] = [0, 1, 2];
/// 「编译目标」卡片里的开关下标（显示顺序）
const BUILD_IDX: [usize; 4] = [6, 7, 5, 4];

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

    let python_exists =
        std::path::Path::new(&layout.python()).is_file() || layout.python() == "python"; // PATH 上的裸命令无法预检
    if python_exists {
        r.ok("python 可执行文件存在");
    } else {
        r.fail(format!("python 不存在：{}", layout.python()));
    }

    // 窗口图标（exe 文件图标由 build.rs 嵌在资源里，运行时看不到）
    match crate::window_icon() {
        Some(i) => r.ok(format!(
            "窗口图标    : assets/icon.png 解码成功（{}×{} RGBA）",
            i.width, i.height
        )),
        None => r.fail("窗口图标：assets/icon.png 解码失败"),
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
    let parsed: serde_json::Value = match serde_json::from_str(text.trim_start_matches('\u{feff}'))
    {
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
    /// 上一帧中部内容（卡片 + 按钮）的屏幕底边，用于把日志面板顶到按钮下方固定间距处
    mid_bottom: f32,
    /// 上一帧日志面板顶边（屏幕坐标），与 `mid_bottom` 之差即实际间距，供布局自检/测试断言
    log_top: f32,
}

/// 按钮区与日志面板之间留出的间距，与按钮上方「卡片 → 按钮」的间距一致
const LOG_GAP: f32 = 20.0;

impl Inner {
    fn try_new() -> Result<Self, String> {
        let layout = Layout::discover()?;
        let store = ConfigStore::load(&layout.sdk_config())?;
        let working = store.all_flags();
        let saved = working.clone();

        // 初始日志：就绪状态 + 使用提示
        let first = store.keys()[0].clone();
        let checked = (0..FLAG_KEYS.len()).filter(|&i| working[0].get(i)).count();
        let log = vec![
            Line {
                stream: Stream::Out,
                text: format!("[就绪] 项目 {first} · 勾选 {checked} 项 · 等待执行"),
            },
            Line {
                stream: Stream::Out,
                text: "提示: 勾选后点「执行」生效；「保存配置」写入 config/sdk_config.json"
                    .to_string(),
            },
        ];

        Ok(Inner {
            layout,
            store,
            selected: 0,
            working,
            saved,
            log,
            runner: None,
            status: "就绪".to_string(),
            mid_bottom: 0.0,
            log_top: 0.0,
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
            self.push(
                Stream::Err,
                "[忽略] 已有任务在运行，请先等它结束或点「停止」。",
            );
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

        // 卡片配色：浅色主题浅灰底、深色主题深灰底
        let card_fill = if dark {
            Color32::from_rgb(0x2a, 0x2d, 0x33)
        } else {
            Color32::from_rgb(0xf6, 0xf7, 0xf9)
        };
        let card_stroke = if dark {
            Color32::from_rgb(0x3a, 0x3d, 0x44)
        } else {
            Color32::from_rgb(0xe4, 0xe6, 0xea)
        };
        // 输出面板固定深色（与设计稿一致），日志配色也不随主题走
        let log_bg = Color32::from_rgb(0x1b, 0x1f, 0x27);

        // ---------------- 顶部：标题 + 项目下拉 + 路径信息 ----------------
        egui::TopBottomPanel::top("top").show(ctx, |ui| {
            ui.add_space(4.0);
            ui.horizontal(|ui| {
                ui.label(RichText::new("OXi SDK 构建工具").size(20.0));
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if self.dirty() {
                        ui.label(
                            RichText::new("● 未保存")
                                .size(12.0)
                                .color(Color32::from_rgb(0xd8, 0x8a, 0x2a)),
                        );
                    }
                    let keys = self.store.keys().to_vec();
                    egui::ComboBox::from_id_salt("project")
                        .selected_text(format!("项目: {}", self.current_key()))
                        .width(190.0)
                        .show_ui(ui, |ui| {
                            for (i, k) in keys.iter().enumerate() {
                                ui.selectable_value(&mut self.selected, i, k.as_str());
                            }
                        });
                });
            });
            ui.separator();
            ui.add_space(8.0);

            let key = self.current_key();
            egui::Frame::default()
                .fill(card_fill)
                .stroke(egui::Stroke::new(1.0, card_stroke))
                .corner_radius(6.0)
                .inner_margin(egui::Margin::symmetric(14, 12))
                .show(ui, |ui| {
                    let weak = ui.visuals().weak_text_color();
                    ui.label(RichText::new("路径信息").size(12.5).color(weak));
                    ui.add_space(2.0);
                    ui.label(
                        RichText::new(format!("sdk_dir: {}", self.store.field_of(&key, "sdk_dir")))
                            .monospace()
                            .size(12.5),
                    );
                    ui.label(
                        RichText::new(format!(
                            "target: {}    prefix: {}    lib: {}",
                            self.store.field_of(&key, "target_root"),
                            self.store.field_of(&key, "prefix"),
                            self.store.field_of(&key, "lib")
                        ))
                        .monospace()
                        .size(12.5),
                    );
                });
            ui.add_space(4.0);
        });

        // ---------------- 底部：输出日志（固定深色面板） ----------------
        let mut clear_requested = false;
        // 高度 = 窗口底边 − 上一帧内容（卡片+按钮）底边 − 固定间距，
        // 这样日志顶部与按钮的间距在任意窗口尺寸下都等于按钮上方那段间距。
        // 首帧还没测量值，先用 390 兜底，第二帧起即精确贴合。
        let win_bottom = ctx.available_rect().bottom();
        let log_h = if self.mid_bottom > 0.0 {
            (win_bottom - self.mid_bottom - LOG_GAP).max(160.0)
        } else {
            390.0
        };
        let log_panel = egui::TopBottomPanel::bottom("log")
            .exact_height(log_h)
            .frame(
                egui::Frame::default()
                    .fill(log_bg)
                    .inner_margin(egui::Margin::symmetric(14, 12)),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.label(
                        RichText::new("输出日志")
                            .size(13.5)
                            .color(Color32::from_rgb(0xc8, 0xd0, 0xdc)),
                    );
                    ui.label(
                        RichText::new(format!(
                            "· {} 行 · {}",
                            self.log.len(),
                            if running {
                                "运行中…"
                            } else {
                                self.status.as_str()
                            }
                        ))
                        .size(12.0)
                        .color(Color32::from_rgb(0x77, 0x80, 0x90)),
                    );
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui.button("清空").on_hover_text("快捷键 Ctrl+L").clicked() {
                            clear_requested = true;
                        }
                    });
                });
                ui.add_space(4.0);

                egui::ScrollArea::vertical()
                    .auto_shrink([false, false])
                    .stick_to_bottom(true)
                    .show_rows(ui, 17.0, self.log.len(), |ui, rows| {
                        for idx in rows {
                            let line = &self.log[idx];
                            let base = RichText::new(&line.text).monospace().size(13.0);
                            let text = match line.stream {
                                Stream::Err => base.color(Color32::from_rgb(0xff, 0x8a, 0x80)),
                                Stream::Out if line.text.starts_with('>') => {
                                    base.color(Color32::from_rgb(0x8f, 0xb8, 0xe8))
                                }
                                Stream::Out
                                    if line.text.starts_with("[已保存]")
                                        || line.text.starts_with("[已重载]")
                                        || line.text.starts_with("[OK]") =>
                                {
                                    base.color(Color32::from_rgb(0x7e, 0xd8, 0x7e))
                                }
                                Stream::Out if line.text.starts_with('[') => {
                                    base.color(Color32::from_rgb(0xa8, 0xb4, 0xc4))
                                }
                                Stream::Out => base.color(Color32::from_rgb(0xde, 0xe4, 0xee)),
                            };
                            ui.label(text);
                        }
                    });
            });
        // 日志面板顶边（屏幕坐标）：与 mid_bottom 之差应恒为 LOG_GAP
        self.log_top = log_panel.response.rect.top();

        if clear_requested || ctx.input(|i| i.modifiers.ctrl && i.key_pressed(egui::Key::L)) {
            self.log.clear();
        }

        // ---------------- 中部：两张卡片 + 动作按钮 ----------------
        egui::CentralPanel::default().show(ctx, |ui| {
            let enabled = !running;
            let mut flags = self.working[self.selected];

            ui.columns(2, |cols| {
                // 左卡：复制进包（含「其他」）
                egui::Frame::default()
                    .fill(card_fill)
                    .stroke(egui::Stroke::new(1.0, card_stroke))
                    .corner_radius(6.0)
                    .inner_margin(egui::Margin::symmetric(14, 12))
                    .show(&mut cols[0], |ui| {
                        let weak = ui.visuals().weak_text_color();
                        ui.label(RichText::new("复制进包").size(13.5).color(weak));
                        ui.add_space(6.0);
                        for i in COPY_IDX {
                            flag_row(ui, enabled, &mut flags, i);
                        }
                        ui.add_space(10.0);
                        ui.separator();
                        ui.add_space(10.0);
                        ui.label(RichText::new("其他").size(13.5).color(weak));
                        flag_row(ui, enabled, &mut flags, 3);
                    });

                // 右卡：编译目标
                egui::Frame::default()
                    .fill(card_fill)
                    .stroke(egui::Stroke::new(1.0, card_stroke))
                    .corner_radius(6.0)
                    .inner_margin(egui::Margin::symmetric(14, 12))
                    .show(&mut cols[1], |ui| {
                        ui.label(
                            RichText::new("编译目标")
                                .size(13.5)
                                .color(ui.visuals().weak_text_color()),
                        );
                        ui.add_space(6.0);
                        for &i in &BUILD_IDX {
                            flag_row(ui, enabled, &mut flags, i);
                        }
                         ui.add_space(6.0);
                        ui.separator();
                        ui.add_space(6.0);
                        flag_row(ui, enabled, &mut flags, 8);
                    });
            });
            self.working[self.selected] = flags;

            ui.add_space(20.0);
            let btn_row = ui.horizontal(|ui| {
                let exec = ui.add_enabled(
                    enabled,
                    egui::Button::new(RichText::new("▶  执行").size(15.0).color(Color32::WHITE))
                        .fill(Color32::from_rgb(0x25, 0x63, 0xEB))
                        .corner_radius(6.0)
                        .min_size(egui::vec2(112.0, 36.0)),
                );
                if exec.clicked() {
                    self.run_build(ctx);
                }

                if ui.add_enabled(enabled, plain_btn("生成文档")).clicked() {
                    self.run_doc(ctx);
                }

                if ui
                    .add_enabled(
                        running,
                        egui::Button::new(RichText::new("停止").size(14.0).color(Color32::from_rgb(0xB9, 0x1C, 0x1C)))
                            .corner_radius(6.0)
                            .min_size(egui::vec2(76.0, 36.0)),
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

                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui
                        .add(plain_btn("自检"))
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

                    if ui
                        .add(plain_btn("重新载入配置"))
                        .on_hover_text("丢弃界面上的改动，重新读 config/sdk_config.json")
                        .clicked()
                    {
                        match ConfigStore::load(&self.layout.sdk_config()) {
                            Ok(s) => {
                                self.store = s;
                                self.working = self.store.all_flags();
                                self.saved = self.working.clone();
                                self.push(Stream::Out, "[已重载] config/sdk_config.json");
                            }
                            Err(e) => self.push(Stream::Err, e),
                        }
                    }

                    if ui
                        .add_enabled(self.dirty(), plain_btn("保存配置"))
                        .on_hover_text("把当前所有项目的勾选写回 config/sdk_config.json")
                        .clicked()
                    {
                        self.save_config();
                    }
                });
            });

            // 记下按钮行的真实底边（屏幕坐标），供下一帧计算日志面板高度
            self.mid_bottom = btn_row.response.rect.bottom();
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
        fonts
            .families
            .entry(family)
            .or_default()
            .push("cjk".to_owned());
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

/// 普通动作按钮（描边、圆角）
fn plain_btn(text: &str) -> egui::Button<'_> {
    egui::Button::new(RichText::new(text.to_owned()).size(14.0))
        .corner_radius(6.0)
        .min_size(egui::vec2(96.0, 34.0))
}

/// 卡片里的一行勾选项：主标签 + 灰色小字说明
fn flag_row(ui: &mut egui::Ui, enabled: bool, flags: &mut Flags, i: usize) {
    let mut v = flags.get(i);
    ui.horizontal(|ui| {
        let resp = ui.add_enabled(enabled, egui::Checkbox::new(&mut v, FLAG_LABELS[i]));
        if resp.changed() {
            flags.set(i, v);
        }
        ui.label(
            RichText::new(FLAG_HINTS[i])
                .size(12.0)
                .color(ui.visuals().weak_text_color()),
        );
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 断言：日志面板顶边与中部内容底边之差 = LOG_GAP（与按钮上方那段间距一致）
    fn gap_after_frames(inner: &mut Inner, size: egui::Vec2) -> f32 {
        let ctx = egui::Context::default();
        for _ in 0..4 {
            let raw = egui::RawInput {
                screen_rect: Some(egui::Rect::from_min_size(egui::Pos2::ZERO, size)),
                ..Default::default()
            };
            let _ = ctx.run(raw, |ctx| inner.ui(ctx));
        }
        inner.log_top - inner.mid_bottom
    }

    #[test]
    fn log_gap_matches_button_gap() {
        let mut inner = Inner::try_new().expect("仓库定位失败：请在 BuildTools 目录下运行测试");
        for size in [
            egui::vec2(1040.0, 780.0),
            egui::vec2(900.0, 640.0),
            egui::vec2(1280.0, 900.0),
        ] {
            let gap = gap_after_frames(&mut inner, size);
            assert!(
                (gap - LOG_GAP).abs() < 1.0,
                "窗口 {size:?} 下日志间距 {gap}，期望 {LOG_GAP}"
            );
        }
    }
}
