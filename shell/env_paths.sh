#!/bin/bash
# ============================================================
# 公共路径配置（WSL 侧读取器）
#
# 唯一真源：<仓库根>/paths.json。用法（放在脚本最前面）：
#     source "$(dirname "${BASH_SOURCE[0]}")/env_paths.sh"
#
# 导出变量：
#   LOCAL_GCC_ROOT / AARCH64_GCC_ROOT   WSL 容器内的 gcc-9.3 与 aarch64 交叉编译器根
#   WSL_CMAKE / WSL_NINJA               容器内的 cmake / ninja
#   ANDROID_PLATFORM / ANDROID_STL      安卓目标平台与 STL（给回退参数用）
#   SCRIPT_REPO_WSL / SCRIPT_PATHS_JSON 仓库根（WSL 形式）与真源文件路径
#   WSL_BUILD_SCRIPT / WSL_OPENCV_SCRIPT 两个 WSL 侧入口脚本
#
# 解析方式用 sed/grep，不依赖 python3（WSL 容器里不一定装）。
# 依赖 paths.json 的格式约定：每个键独占一行、值是用双引号包住的字符串。
# ============================================================

if [ -n "${SCRIPT_ENV_PATHS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
SCRIPT_ENV_PATHS_LOADED=1

SCRIPT_REPO_WSL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATHS_JSON="${SCRIPT_REPO_WSL}/paths.json"

if [ ! -f "${SCRIPT_PATHS_JSON}" ]; then
    echo "[ERROR] 找不到公共路径配置: ${SCRIPT_PATHS_JSON}" >&2
    return 1 2>/dev/null || exit 1
fi

# 取 "<section>" 块里 "<key>" 的字符串值
paths_get()
{
    local section="$1" key="$2" value
    value="$(sed -n "/^  \"${section}\": {/,/^  }/p" "${SCRIPT_PATHS_JSON}" \
        | grep -m1 "\"${key}\":" \
        | sed -E 's/^[^:]*: *"([^"]*)".*$/\1/')"
    printf '%s' "${value}"
}

LOCAL_GCC_ROOT="$(paths_get wsl gcc_x64_root)"
AARCH64_GCC_ROOT="$(paths_get wsl gcc_aarch64_root)"
WSL_CMAKE="$(paths_get wsl cmake)"
WSL_NINJA="$(paths_get wsl ninja)"
WSL_PYTHON="$(paths_get wsl python)"

ANDROID_PLATFORM="$(paths_get android platform)"
ANDROID_STL="$(paths_get android stl)"

WSL_BUILD_SCRIPT="${SCRIPT_REPO_WSL}/shell/buildOXiAll.sh"
WSL_OPENCV_SCRIPT="${SCRIPT_REPO_WSL}/shell/opencv-wsl.sh"

if [ -z "${LOCAL_GCC_ROOT}" ] || [ -z "${AARCH64_GCC_ROOT}" ]; then
    echo "[ERROR] 解析 ${SCRIPT_PATHS_JSON} 失败（检查 wsl.gcc_x64_root / wsl.gcc_aarch64_root 是否为单行字符串）" >&2
    return 1 2>/dev/null || exit 1
fi

export LOCAL_GCC_ROOT AARCH64_GCC_ROOT WSL_CMAKE WSL_NINJA WSL_PYTHON
export ANDROID_PLATFORM ANDROID_STL
export SCRIPT_REPO_WSL SCRIPT_PATHS_JSON WSL_BUILD_SCRIPT WSL_OPENCV_SCRIPT
