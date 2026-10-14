# encoding:utf-8
"""
公共路径配置读取（唯一真源：仓库根 paths.json）。

和 ps/env_paths.ps1、shell/env_paths.sh、bat/config.bat 读的是同一个文件 —— 
改机器只改 paths.json，不要在 Python 脚本里再写死这类绝对路径。

用法（py 目录是 sys.path 根，与 utils.fileUtils 一致）：
    from utils.env_paths import CMAKE, NINJA, ANDROID_NDK, NDK_TOOLCHAIN
    from utils.env_paths import win_to_wsl, wsl_to_win, paths
"""
import json
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PATHS_FILE = REPO_ROOT / "paths.json"


def paths():
    """读取（并缓存）paths.json 的原始字典。"""
    global _CACHE
    if _CACHE is None:
        with open(PATHS_FILE, encoding="utf-8") as f:
            _CACHE = json.load(f)
    return _CACHE


_CACHE = None


def win_to_wsl(win_path):
    """Windows 路径 -> WSL 路径：D:\\a\\b 或 D:/a/b  =>  /mnt/d/a/b"""
    if not win_path:
        return win_path
    p = str(win_path).replace("\\", "/")
    if len(p) > 1 and p[1] == ":" and p[0].isalpha():
        return "/mnt/%s/%s" % (p[0].lower(), p[2:].lstrip("/"))
    return p


def wsl_to_win(wsl_path):
    """WSL 路径 -> Windows 路径：/mnt/d/a/b  =>  D:\\a\\b"""
    if not wsl_path:
        return wsl_path
    p = str(wsl_path).replace("\\", "/")
    m = p.split("/")
    if len(m) >= 4 and m[1] == "mnt" and len(m[2]) == 1:
        return "%s:\\%s" % (m[2].upper(), "\\".join(m[3:]))
    return str(wsl_path).replace("/", "\\")


_cfg = paths()
WINDOWS = _cfg["windows"]
WSL = _cfg["wsl"]
ANDROID = _cfg["android"]
VS = _cfg["vs"]

# ---- Windows 侧工具 ----
CMAKE = WINDOWS["cmake"]
NINJA = WINDOWS["ninja"]
MSBUILD = WINDOWS["msbuild"]
PYTHON = WINDOWS["python"]
ANDROID_SDK = WINDOWS["android_sdk"]
ANDROID_NDK = WINDOWS["android_ndk"]

# ---- 由 NDK 根派生（换 NDK 版本只改 paths.json 的 android_ndk）----
NDK_TOOLCHAIN = "%s/build/cmake/android.toolchain.cmake" % ANDROID_NDK
LLVM_BIN = "%s/toolchains/llvm/prebuilt/windows-x86_64/bin" % ANDROID_NDK
LLVM_STRIP = "%s/llvm-strip.exe" % LLVM_BIN
LLVM_READELF = "%s/llvm-readelf.exe" % LLVM_BIN

# ---- WSL 容器侧 ----
WSL_CMAKE = WSL["cmake"]
WSL_NINJA = WSL["ninja"]
WSL_PYTHON = WSL["python"]
WSL_GCC_X64_ROOT = WSL["gcc_x64_root"]
WSL_GCC_AARCH64_ROOT = WSL["gcc_aarch64_root"]

# ---- 构建常量 ----
ANDROID_PLATFORM = ANDROID["platform"]
ANDROID_STL = ANDROID["stl"]
ANDROID_ABIS = [a for a in ANDROID.get("abis", "").split(",") if a]
VS_GENERATOR = VS["generator"]
VS_ARCH_X86 = VS["arch_x86"]
VS_ARCH_X64 = VS["arch_x64"]

# ---- 仓库自身 ----
REPO_ROOT_WSL = win_to_wsl(str(REPO_ROOT))
