//! OXiScan SDK 构建工具（桌面版）
//!
//! 把 `git/script` 下的构建/打包/文档脚本包一层界面：
//!   · 项目下拉框（读 ps/sdk_config.json 的键）
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

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("OXiScan SDK 构建工具")
            .with_inner_size([1040.0, 780.0])
            .with_min_inner_size([780.0, 540.0]),
        ..Default::default()
    };

    eframe::run_native(
        "OXiScan SDK 构建工具",
        options,
        Box::new(|cc| Ok(Box::new(app::App::new(cc)))),
    )
}
