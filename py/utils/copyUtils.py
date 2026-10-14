#!/usr/bin/python
# encoding:utf-8
import os
import shutil

from utils.fileUtils import copy_files_by_suffix, remove_dir, safe_mkdir


# ------------------------------------------------------------
# 目录名约定（与 ps 一致，不要随意加版本后缀）：
#   Windows exe/dll : win_X86Demo / win_X64Demo
#   Windows 源码    : simpleWin
#   Android 源码    : simpleAndroid
#   Qt Linux 源码   : simpleLinux
# ------------------------------------------------------------

def copy_win_exe(src_dir: str, tg_root: str):
    """
    复制 Windows x86/x64 exe dll。

    exe/dll 的落点有两种工程形态（A910_win、oxiscansdk_win_mut 这类只有 CMake 产物），
    所以必须走 resolve_win_demo_dir 回退，不能只看 Release / x64\\Release。
    对应 ps/copyUtils.ps1 的 Copy-WinExe。
    """
    for arch in ("x86", "x64"):
        dst = os.path.join(tg_root, "win_X64Demo" if arch == "x64" else "win_X86Demo")
        src = resolve_win_demo_dir(src_dir, arch)

        if not src:
            tried = "  |  ".join(get_win_demo_candidate_dirs(src_dir, arch))
            print(f"[跳过] {arch} 未找到含 .exe 的输出目录，已尝试: {tried}")
            continue

        print(f"[{arch} 产物目录] {src}")
        copy_files_by_suffix(src, dst, [".exe", ".dll"])


def copy_android_apk(src_dir: str, target_dir: str):
    """复制Android debug APK"""
    src_apk_root = os.path.join(src_dir, "app", "build", "outputs", "apk", "debug")
    copy_files_by_suffix(src_apk_root, target_dir, [".apk"])


# ------------------------------------------------------------
# Windows 产物目录解析
#   同一套 demo 代码有两种工程形态，exe/dll 落点不同：
#     VS 工程   : <SrcDir>\Release                    / <SrcDir>\x64\Release
#     CMake 工程: <SrcDir>\cmake-build-release-vs2019_x86\Release
#                 <SrcDir>\cmake-build-release-vs2019_x64\Release
#   （A910_win、oxiscansdk_win_mut 这类只有 CMake 产物）
# ------------------------------------------------------------
def get_win_demo_candidate_dirs(src_dir: str, arch: str):
    """按优先级给出该架构的候选输出目录（VS 优先，其次 CMake）。对应 ps 的 Get-WinDemoCandidateDirs。"""
    if arch == "x64":
        vs_sub = os.path.join("x64", "Release")
        cmake_sub = os.path.join("cmake-build-release-vs2019_x64", "Release")
    else:
        vs_sub = "Release"
        cmake_sub = os.path.join("cmake-build-release-vs2019_x86", "Release")

    return [os.path.join(src_dir, vs_sub), os.path.join(src_dir, cmake_sub)]


def resolve_win_demo_dir(src_dir: str, arch: str):
    """
    按优先级挑出该架构下真正含有 .exe 的输出目录：
    先看 VS 的 Release / x64\\Release，里面没有 .exe（或目录不存在）时，
    回退到 CMake 的 cmake-build-release-vs2019_<arch>\\Release。

    写死 VS 路径会让包里缺 demo 目录（真实案例 D:/G6SDKLib/A910/G6SDKv1.0.51.83）。
    返回命中的目录字符串；候选目录都没有 .exe 时返回 None。
    """
    for d in get_win_demo_candidate_dirs(src_dir, arch):
        if not os.path.isdir(d):
            continue
        for root, _dirs, files in os.walk(d):
            if any(f.lower().endswith(".exe") for f in files):
                return d
    return None


# ------------------------------------------------------------
# Qt Linux 预编译库
#   <QtDir>\linux 是源码树之外的预编译产物（按架构分子目录，如 aarch64/x64/arm）。
#   WSL 下建的 .so 多为符号链接，整棵树一把梭拷容易拷成 0 字节甚至卡住，
#   这里按文件逐个拷（copy2 跟随链接取真实内容），并统计各架构文件数。
#   对应 ps/OXi.ps1 的 Find-QtLinuxLibDir / Copy-QtLinuxLibs。
# ------------------------------------------------------------
def find_qt_linux_lib_dir(qt_dir: str):
    """在 Qt 工程目录下找预编译库目录：<QtDir>\\linux（大小写不敏感，实际多为 Linux）。找不到返回 None。"""
    if not os.path.isdir(qt_dir):
        return None

    for name in sorted(os.listdir(qt_dir)):
        p = os.path.join(qt_dir, name)
        if os.path.isdir(p) and name.lower() == "linux":
            return p
    return None


def copy_qt_linux_libs(qt_dir: str, dst_dir: str) -> bool:
    """
    把 <QtDir>\\linux 下的预编译库整份拷进 <dst_dir>\\<原名>。**只拷贝，不做任何构建。**

    返回是否真的复制到了文件。
    """
    lib_dir = find_qt_linux_lib_dir(qt_dir)
    if not lib_dir:
        print(f"[跳过] {qt_dir} 下没有 linux 库目录")
        return False

    dst_lib = os.path.join(dst_dir, os.path.basename(lib_dir))
    if os.path.exists(dst_lib):
        remove_dir(dst_lib)
    safe_mkdir(dst_lib)

    copied = 0
    failed = 0
    for root, dirs, files in os.walk(lib_dir):
        # .workbuddy 之类的工程元数据目录剪掉（该目录理论上只有库文件，做个兜底）
        dirs[:] = [d for d in dirs if d != ".workbuddy"]
        for name in files:
            src = os.path.join(root, name)
            rel = os.path.relpath(src, lib_dir)
            dst_file = os.path.join(dst_lib, rel)
            safe_mkdir(os.path.dirname(dst_file))
            try:
                shutil.copy2(src, dst_file)
                copied += 1
            except Exception as e:
                failed += 1
                print(f"[Qt Linux库] 复制失败: {rel} ({e})")

    archs = []
    for name in sorted(os.listdir(dst_lib)):
        p = os.path.join(dst_lib, name)
        if os.path.isdir(p):
            n = sum(len(fs) for _r, _d, fs in os.walk(p))
            archs.append(f"{name}({n})")

    summary = f"复制 {copied} 个文件"
    if failed:
        summary += f"，失败 {failed} 个"
    if archs:
        summary += "（" + ", ".join(archs) + "）"
    print(f"[Qt Linux库] {os.path.basename(lib_dir)}: {summary}")

    return copied > 0


# ============================================================
# 打包忽略目录（ps 侧一一对应：ps/copyUtils.ps1 的 Get-PackIgnoreDirs）
# 统一在这里定义，别在各处复制粘贴 —— 新增一类要忽略的目录只改这一处。
#   * .workbuddy / .git / .idea / .vs 是编辑器或工具目录，任何一份 SDK 都不该带
#   * cmake-build* 用前缀匹配（不能写精确名）：真实目录名是
#     cmake-build-release-vs2019_x64 / cmake-build-debug 之类
#   * "cmake"（无横线）不在列表里 —— A910_qt/cmake 下是 toolchain-*.cmake 源码
# ============================================================
PACK_IGNORE_DIRS = {
    # simpleWin（Windows 源码树）
    "win": ("Release", "x64", ".vs", ".vscode", ".git", ".idea", ".workbuddy", "CMakeFiles"),
    # simpleAndroid（Android 源码树）
    "android": (".gradle", ".git", ".idea", ".workbuddy", ".cxx", "build"),
    # simpleLinux（Qt 源码树）
    "qt": (".git", ".idea", ".vs", ".vscode", ".workbuddy", "build", ".cxx", "CMakeFiles"),
    # doc（文档目录）
    "doc": (".git", ".workbuddy"),
}


def make_pack_ignore(kind: str, extra_dirs=()):
    """
    生成 shutil.copytree 的 ignore 回调：按 kind 排除 PACK_IGNORE_DIRS 里的目录，
    外加所有 cmake-build*（前缀匹配）与调用方额外指定的 extra_dirs。

    extra_dirs 供 Copy-QtSimpleLinux 用：把 linux 预编译库目录从源码树那趟拷贝里摘出来，
    再交给 copy_qt_linux_libs 单独逐文件拷（见 ps 侧同名逻辑）。
    """
    dirs = tuple(PACK_IGNORE_DIRS[kind]) + tuple(extra_dirs)

    def _ignore(src_dir, names):
        return [
            n for n in names
            if os.path.isdir(os.path.join(src_dir, n))
            and (n in dirs or n.startswith("cmake-build"))
        ]

    return _ignore


# 与 ps/copyUtils.ps1 的 Copy-WinSourceCode / Copy-AndroidSourceCode /
# Copy-QtSimpleLinux / Copy-Doc 一一对应
ignore_win_code = make_pack_ignore("win")
ignore_android_code = make_pack_ignore("android")
ignore_qt_simple_linux = make_pack_ignore("qt")
ignore_doc = make_pack_ignore("doc")


def _copy_source_tree(src_dir: str, dst_dir: str, ignore, label: str) -> bool:
    """
    源码树整体复制：源不存在只提示（对应 ps 的 Copy-DirectoryFiltered），
    目标已存在先删掉再建（shutil.copytree 目标存在会直接抛 FileExistsError）。
    """
    if not os.path.isdir(src_dir):
        print(f"[跳过] {label} 源目录不存在: {src_dir}")
        return False

    if os.path.exists(dst_dir):
        remove_dir(dst_dir)
    safe_mkdir(os.path.dirname(dst_dir))

    shutil.copytree(src_dir, dst_dir, ignore=ignore)
    print(f"[复制{label}] {src_dir} -> {dst_dir}")
    return True


def copy_win_source_code(src_dir: str, target_root: str) -> bool:
    """simpleWin：排除 IDE/构建中间目录 + 工程元数据（对应 ps 的 Copy-WinSourceCode）"""
    dst_code = os.path.join(target_root, "simpleWin")
    return _copy_source_tree(src_dir, dst_code, ignore_win_code, "Windows源码")


def copy_android_source_code(src_dir: str, target_root: str) -> bool:
    """simpleAndroid：同样排除 .gradle / build / .cxx 等（对应 ps 的 Copy-AndroidSourceCode）"""
    dst_code = os.path.join(target_root, "simpleAndroid")
    return _copy_source_tree(src_dir, dst_code, ignore_android_code, "Android源码")
