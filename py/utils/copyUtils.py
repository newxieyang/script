#!/usr/bin/python
# encoding:utf-8
import os
import shutil

from utils.fileUtils import copy_files_by_suffix, remove_dir

def copy_win_exe(src_dir: str, tg_root: str):
    """复制Windows x86/x64 exe dll"""
    # x86
    src_x86 = os.path.join(src_dir, "Release")
    dst_x86 = os.path.join(tg_root, "win_X86Demo")
    copy_files_by_suffix(src_x86, dst_x86, [".exe", ".dll"])

    # x64
    src_x64 = os.path.join(src_dir, "x64", "Release")
    dst_x64 = os.path.join(tg_root, "win_X64Demo")
    copy_files_by_suffix(src_x64, dst_x64, [".exe", ".dll"])


def copy_android_apk(src_dir: str, target_dir: str):
    """复制Android debug APK"""
    src_apk_root = os.path.join(src_dir, "app", "build", "outputs", "apk", "debug")
    copy_files_by_suffix(src_apk_root, target_dir, [".apk"])


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


def make_pack_ignore(kind: str):
    """
    生成 shutil.copytree 的 ignore 回调：按 kind 排除 PACK_IGNORE_DIRS 里的目录，
    外加所有 cmake-build*（前缀匹配）。
    """
    dirs = PACK_IGNORE_DIRS[kind]

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


def copy_win_source_code(src_dir: str, target_root: str):
    dst_code = os.path.join(target_root, "simpleWin")
    if os.path.exists(dst_code):
        remove_dir(dst_code)
    shutil.copytree(src_dir, dst_code, ignore=ignore_win_code)
    print(f"[复制Windows源码] {src_dir} -> {dst_code}")


def copy_android_source_code(src_dir: str, target_root: str):
    dst_code = os.path.join(target_root,  "simpleAndroid")
    shutil.copytree(src_dir, dst_code, ignore=ignore_android_code)
    print(f"[复制Android源码] {src_dir} -> {dst_code}")