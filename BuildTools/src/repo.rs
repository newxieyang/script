//! 仓库布局定位：找到 `git/oxi/script` 根（含 `config/paths.json` 与 `config/sdk_config.json`），
//! 并给出各处脚本 / 配置的绝对路径。
//!
//! 之所以不写死路径：exe 可能被 `cargo run` 启动（cwd = BuildTools/）、
//! 也可能被双击（cwd = exe 所在目录），还可能被复制到别处运行。

use std::path::{Path, PathBuf};

pub struct Layout {
    root: PathBuf,
}

impl Layout {
    /// 按「环境变量 → cwd → exe 所在目录」的顺序，各自逐级上溯找仓库根。
    pub fn discover() -> Result<Self, String> {
        let mut anchors: Vec<PathBuf> = Vec::new();

        if let Ok(v) = std::env::var("SCRIPT_REPO_ROOT") {
            if !v.trim().is_empty() {
                anchors.push(PathBuf::from(v));
            }
        }
        if let Ok(cwd) = std::env::current_dir() {
            anchors.push(cwd);
        }
        if let Ok(exe) = std::env::current_exe() {
            if let Some(dir) = exe.parent() {
                anchors.push(dir.to_path_buf());
            }
        }

        for anchor in &anchors {
            let mut cur: Option<&Path> = Some(anchor.as_path());
            while let Some(dir) = cur {
                if Self::is_repo_root(dir) {
                    return Ok(Layout { root: dir.to_path_buf() });
                }
                cur = dir.parent();
            }
        }

        Err(format!(
            "找不到仓库根（要求同时存在 config/paths.json 与 config/sdk_config.json）。\n已尝试的起点：{}",
            anchors
                .iter()
                .map(|p| p.display().to_string())
                .collect::<Vec<_>>()
                .join(" | ")
        ))
    }

    fn is_repo_root(dir: &Path) -> bool {
        dir.join("config").join("paths.json").is_file()
            && dir.join("config").join("sdk_config.json").is_file()
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// 所有配置文件的目录（`config/`）。
    pub fn config_dir(&self) -> PathBuf {
        self.root.join("config")
    }

    pub fn paths_json(&self) -> PathBuf {
        self.config_dir().join("paths.json")
    }

    /// 默认配置（需求 1）：`config/sdk_config.json`
    pub fn sdk_config(&self) -> PathBuf {
        self.config_dir().join("sdk_config.json")
    }

    pub fn build_script(&self) -> PathBuf {
        self.root.join("ps").join("buildOXiAll.ps1")
    }

    pub fn api_script(&self) -> PathBuf {
        self.root.join("py").join("genSDKAPI.py")
    }

    pub fn py_dir(&self) -> PathBuf {
        self.root.join("py")
    }

    /// adb 无线调试脚本：取设备 IP 并让 adb 切到 TCP 5555。
    pub fn wifi_script(&self) -> PathBuf {
        self.root.join("bat").join("wifi.bat")
    }

    /// 读 `config/paths.json` 的 `windows.python`；读不到就回落到 PATH 上的 `python`。
    pub fn python(&self) -> String {
        const FALLBACK: &str = "python";
        let Ok(text) = std::fs::read_to_string(self.paths_json()) else {
            return FALLBACK.to_string();
        };
        let Ok(v) = serde_json::from_str::<serde_json::Value>(&text) else {
            return FALLBACK.to_string();
        };
        v.get("windows")
            .and_then(|w| w.get("python"))
            .and_then(|p| p.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| FALLBACK.to_string())
    }

    /// 运行期生成的临时配置（把界面上的勾选覆盖写进项目配置后交给 ps 脚本）。
    pub fn runtime_config_path(&self) -> PathBuf {
        std::env::temp_dir()
            .join("BuildTools")
            .join("sdk_config.gui.json")
    }
}
