//! OXiScan SDK 构建工具（桌面版）
//!
//! 把 `git/script` 下的构建/打包/文档脚本包一层界面：
//!   · 项目下拉框（读 config/sdk_config.json 的键）
//!   · 9 个构建开关（勾选后点「执行」生效）
//!   · 「执行」= powershell ps/buildOXiAll.ps1 -SdkKey <key> -ConfigFile <临时配置>
//!   · 「生成文档」= python py/genSDKAPI.py <key>
//!   · 底部输出面板实时显示子进程 stdout/stderr
//!
//! 调试构建保留控制台（方便看 --selftest 输出）；发布构建不弹黑框。

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod app;
mod config;
mod repo;
mod runner;

use eframe::egui;

fn main() -> Result<(), eframe::Error> {
    // 无窗口自检：cargo run -- --selftest
    if std::env::args().skip(1).any(|a| a == "--selftest") {
        let code = app::App::selftest();
        std::process::exit(code);
    }

    let mut viewport = egui::ViewportBuilder::default()
        .with_title("OXi SDK 构建工具")
        .with_inner_size([1040.0, 780.0])
        .with_min_inner_size([780.0, 540.0]);
    if let Some(icon) = window_icon() {
        viewport = viewport.with_icon(icon);
    }

    let options = eframe::NativeOptions {
        viewport,
        ..Default::default()
    };

    eframe::run_native(
        "OXi SDK 构建工具",
        options,
        Box::new(|cc| Ok(Box::new(app::App::new(cc)))),
    )
}

/// 窗口图标：assets/icon.png（256×256 RGBA，由 avator_transparent.png 缩小而来）。
///
/// 编译期嵌进二进制，解码失败就不设图标（不让它把启动搞挂）。
/// exe 文件本身的图标由 build.rs 通过 assets/app.rc 嵌入。
pub(crate) fn window_icon() -> Option<egui::IconData> {
    let bytes = include_bytes!("../assets/icon.png");
    let mut decoder = png::Decoder::new(std::io::Cursor::new(&bytes[..]));
    // 源图本就是 RGBA8，这里只是保证输出位深为 8
    decoder.set_transformations(png::Transformations::normalize_to_color8());
    let mut reader = match decoder.read_info() {
        Ok(r) => r,
        Err(e) => {
            eprintln!("[警告] 读取 assets/icon.png 失败，窗口使用默认图标：{e}");
            return None;
        }
    };
    let mut buf = vec![0u8; reader.output_buffer_size()];
    let info = match reader.next_frame(&mut buf) {
        Ok(i) => i,
        Err(e) => {
            eprintln!("[警告] 解码 assets/icon.png 失败，窗口使用默认图标：{e}");
            return None;
        }
    };
    if info.color_type != png::ColorType::Rgba {
        eprintln!("[警告] assets/icon.png 不是 RGBA，窗口使用默认图标");
        return None;
    }
    buf.truncate(info.buffer_size());
    Some(egui::IconData {
        rgba: buf,
        width: info.width,
        height: info.height,
    })
}
