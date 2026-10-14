//! 构建脚本：把 assets/icon.ico 作为图标资源嵌入 exe（Windows 专用）。
//!
//! 非 Windows 平台直接跳过——embed-resource 只在 Windows 上有意义。
//! 本机 MSVC 的 rc.exe 不在 PATH 里，embed-resource 会自己去 Windows SDK 目录找。

fn main() {
    println!("cargo:rerun-if-changed=assets/app.rc");
    println!("cargo:rerun-if-changed=assets/icon.ico");

    #[cfg(windows)]
    if let Err(e) = embed_resource::compile("assets/app.rc", embed_resource::NONE)
        .manifest_optional()
    {
        // 编译资源失败不该让整个构建挂掉（最坏情况：exe 用默认图标）
        println!("cargo:warning=嵌入 exe 图标失败：{e}");
    }
}
