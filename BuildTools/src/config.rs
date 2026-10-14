//! `config/sdk_config.json` 的读写。
//!
//! 只把需求里点名的 9 个键当作"可勾选项"，其余字段（sdk_dir / prefix / lib /
//! header_keyword / headers / doc ...）一律原样保留 —— 界面保存或生成临时配置时
//! 靠 serde_json::Value 整体克隆，不需要为每个机型建结构体。

use serde::Serialize;
use serde_json::Value;
use std::path::{Path, PathBuf};

/// 需求 2 点名的 9 个可勾选项（顺序即界面上的展示顺序）
pub const FLAG_KEYS: [&str; 9] = [
    "copy_win_lib",
    "copy_android_lib",
    "copy_linux_lib",
    "keep_latest_doc",
    "build_static",
    "build_android",
    "build_windows",
    "build_linux",
    "should_package",
];

/// 每个开关的界面短说明（灰色小字，显示在主标签右侧）
pub const FLAG_HINTS: [&str; 9] = [
    "Win + Demo 进包",
    "so + apk 进包",
    "Qt 源码 + 预编译库",
    "打包时清理旧文档",
    "同时输出 .a / .lib",
    "arm64-v8a / armeabi-v7a",
    "x86 / x64",
    "x64 / aarch64 · WSL",
    "调用 OXi.ps1 出包",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Flags([bool; 9]);

impl Default for Flags {
    fn default() -> Self {
        Flags([false; 9])
    }
}

impl Flags {
    pub fn get(&self, i: usize) -> bool {
        self.0[i]
    }

    pub fn set(&mut self, i: usize, v: bool) {
        self.0[i] = v;
    }

    fn from_project(v: &Value) -> Self {
        let mut f = Flags::default();
        for (i, key) in FLAG_KEYS.iter().enumerate() {
            if let Some(b) = v.get(key).and_then(|x| x.as_bool()) {
                f.0[i] = b;
            }
        }
        f
    }

    fn apply_to(&self, v: &mut Value) {
        for (i, key) in FLAG_KEYS.iter().enumerate() {
            v[key] = Value::Bool(self.0[i]);
        }
    }
}

pub struct ConfigStore {
    path: PathBuf,
    doc: Value,
    keys: Vec<String>,
    /// 是否以 UTF-8 BOM 写出（tmp 副本给 PowerShell 读，带 BOM 更稳；
    /// 回写仓库里的 sdk_config.json 则遵循仓库"json 无 BOM"的约定）
    bom: bool,
}

impl ConfigStore {
    pub fn load(path: &Path) -> Result<Self, String> {
        let text = std::fs::read_to_string(path)
            .map_err(|e| format!("读取配置失败 {}: {e}", path.display()))?;
        // 容忍 UTF-8 BOM：PowerShell / 记事本另存都可能带上，serde_json 不认
        let text = text.trim_start_matches('\u{feff}');
        let doc: Value = serde_json::from_str(text)
            .map_err(|e| format!("解析配置失败 {}: {e}", path.display()))?;

        let obj = doc
            .as_object()
            .ok_or_else(|| format!("配置根节点不是对象: {}", path.display()))?;
        let keys: Vec<String> = obj.keys().cloned().collect();
        if keys.is_empty() {
            return Err(format!("配置里没有任何项目: {}", path.display()));
        }

        Ok(ConfigStore {
            path: path.to_path_buf(),
            doc,
            keys,
            bom: false,
        })
    }

    pub fn keys(&self) -> &[String] {
        &self.keys
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn flags_of(&self, key: &str) -> Flags {
        match self.doc.get(key) {
            Some(v) => Flags::from_project(v),
            None => Flags::default(),
        }
    }

    /// 把勾选状态写回内存中的文档
    pub fn set_flags(&mut self, key: &str, flags: Flags) {
        if let Some(v) = self.doc.get_mut(key) {
            flags.apply_to(v);
        }
    }

    /// 全部项目的当前勾选（下标与 `keys()` 对齐），用于初始化界面的工作副本
    pub fn all_flags(&self) -> Vec<Flags> {
        self.keys.iter().map(|k| self.flags_of(k)).collect()
    }

    /// 把界面的工作副本灌回内存文档（配合 `save()` 落盘）
    pub fn apply_working(&mut self, working: &[Flags]) {
        // 先取出键名再改，避免 `self.keys` 的不可变借用与 `&mut self` 打架
        for i in 0..self.keys.len().min(working.len()) {
            let key = self.keys[i].clone();
            self.set_flags(&key, working[i]);
        }
    }

    /// 读取项目的某个字符串字段（路径信息卡片用）
    pub fn field_of(&self, key: &str, field: &str) -> String {
        self.doc
            .get(key)
            .and_then(|v| v.get(field))
            .and_then(|x| x.as_str())
            .unwrap_or("-")
            .to_string()
    }

    fn serialize(&self, bom: bool) -> Result<Vec<u8>, String> {
        // 4 空格缩进：与仓库里 config/sdk_config.json 的原格式一致。
        // 默认的 to_string_pretty 是 2 空格，会让每次「保存配置」都变成整文件 diff。
        let mut body = Vec::new();
        let fmt = serde_json::ser::PrettyFormatter::with_indent(b"    ");
        let mut ser = serde_json::Serializer::with_formatter(&mut body, fmt);
        self.doc
            .serialize(&mut ser)
            .map_err(|e| format!("序列化配置失败: {e}"))?;
        body.push(b'\n');

        // 仓库约定：json = 无 BOM + CRLF。统一转 CRLF，避免保存后 git 全文件报改动。
        let mut out = Vec::with_capacity(body.len() + 3);
        if bom {
            out.extend_from_slice(b"\xef\xbb\xbf");
        }
        for b in body {
            if b == b'\n' {
                out.extend_from_slice(b"\r\n");
            } else {
                out.push(b);
            }
        }
        Ok(out)
    }

    /// 回写 `config/sdk_config.json`（无 BOM，遵循仓库约定）
    pub fn save(&self) -> Result<(), String> {
        let bytes = self.serialize(self.bom)?;
        std::fs::write(&self.path, bytes)
            .map_err(|e| format!("写回配置失败 {}: {e}", self.path.display()))
    }

    /// 生成给 ps 脚本用的临时配置：整份克隆 + 用界面上的勾选覆盖全部项目。
    /// 路径按 `buildOXiAll.ps1 -ConfigFile` 传入。
    /// `working` 与 `keys()` 下标一一对应。
    pub fn write_runtime_copy(&self, working: &[Flags], out: &Path) -> Result<(), String> {
        let mut doc = self.doc.clone();
        for (i, key) in self.keys.iter().enumerate() {
            let Some(f) = working.get(i) else { continue };
            match doc.get_mut(key) {
                Some(v) => f.apply_to(v),
                None => return Err(format!("配置里没有项目 '{key}'")),
            }
        }

        if let Some(dir) = out.parent() {
            std::fs::create_dir_all(dir).map_err(|e| format!("创建目录失败 {}: {e}", dir.display()))?;
        }

        let mut body = serde_json::to_string_pretty(&doc)
            .map_err(|e| format!("序列化临时配置失败: {e}"))?
            .into_bytes();
        body.push(b'\n');
        // 临时文件是给 PowerShell 5.1 读的：带 BOM 才会被当作 UTF-8，
        // 否则它按 ANSI(GBK) 解码 —— 一旦配置里出现中文就乱码。
        let mut bytes = Vec::with_capacity(body.len() + 3);
        bytes.extend_from_slice(b"\xef\xbb\xbf");
        bytes.extend_from_slice(&body);

        std::fs::write(out, bytes).map_err(|e| format!("写临时配置失败 {}: {e}", out.display()))
    }
}
#[cfg(test)]
mod tests {
    use super::*;

    /// save() 必须按仓库格式落盘（4 空格缩进 + CRLF、无 BOM），
    /// 否则每次「保存配置」都会把 config/sdk_config.json 变成整文件 diff。
    #[test]
    fn save_keeps_repo_format() {
        let dir = std::env::temp_dir().join("BuildTools_test");
        std::fs::create_dir_all(&dir).unwrap();
        let p = dir.join("fmt_probe.json");
        std::fs::write(&p, b"{\r\n    \"A\": {\r\n        \"copy_win_lib\": true\r\n    }\r\n}\r\n")
            .unwrap();

        let store = ConfigStore::load(&p).unwrap();
        store.save().unwrap();

        let bytes = std::fs::read(&p).unwrap();
        assert_eq!(
            bytes,
            b"{\r\n    \"A\": {\r\n        \"copy_win_lib\": true\r\n    }\r\n}\r\n"
        );
    }
}
