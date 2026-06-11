#!/bin/bash

# 开启错误检查，任何命令失败则立即退出
set -e

# --- 1. 基础路径定义 ---
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR="$SCRIPT_DIR/oxiscansdk"
SDK_EXPORT_DIR="$SCRIPT_DIR/GSerQtSimple"
BUILD_BASE_DIR="$SCRIPT_DIR/build" # 修正了你的拼写错误 "builid"

# --- 2. 架构检测函数 ---
get_arch_name() {
    local distro=$(. /etc/os-release && echo "$ID" | tr '[:upper:]' '[:lower:]')
    local cpu=$(uname -m)
    local cpu_type="x64"
    
    [[ "$cpu" =~ ^(arm|aarch64)$ ]] && cpu_type="arm"
    
    case "$distro" in
        ubuntu|kylin|debian) echo "${distro}_${cpu_type}" ;;
        *) echo "linux_generic" ;;
    esac
}

# --- 3. 获取 CMake 执行路径函数 ---
find_cmake() {
    # 如果系统自带 cmake 且可用，优先使用
    if command -v cmake >/dev/null 2>&1; then
        echo "cmake"
        return
    fi
    
    # 查找本地路径下的 cmake (假设放在脚本同级目录)
    local local_cmake=$(find "$SCRIPT_DIR" -name cmake -type f -perm -u+x | head -n 1)
    if [ -n "$local_cmake" ]; then
        echo "$local_cmake"
    else
        echo "Error: CMake not found!" >&2
        exit 1
    fi
}

# --- 4. 执行构建 ---
ARCH_TAG=$(get_arch_name)
BUILD_DIR="$BUILD_BASE_DIR/$ARCH_TAG"
CMAKE_BIN=$(find_cmake)

echo "检测到环境: $ARCH_TAG"
echo "使用 CMake: $CMAKE_BIN"

mkdir -p "$BUILD_DIR"

echo "正在生成构建文件..."
"$CMAKE_BIN" -S "$PROJECT_DIR" -B "$BUILD_DIR"

echo "正在编译..."
cd "$BUILD_DIR"
make -j$(nproc)

# --- 5. 资源拷贝 ---
echo "正在导出 SDK 文件..."
# 确保目标目录存在
mkdir -p "${SDK_EXPORT_DIR}/kylin"

cp -f "${PROJECT_DIR}/base/include/OXiScan_def.h" "${SDK_EXPORT_DIR}/"
cp -f "${PROJECT_DIR}/base/include/OXiScan_err.h" "${SDK_EXPORT_DIR}/"
cp -f "${PROJECT_DIR}/base/export/OXiScan_Api.h" "${SDK_EXPORT_DIR}/"
cp -f "${BUILD_DIR}/libFAP.so" "${SDK_EXPORT_DIR}/kylin/"

echo "构建成功，文件已导出至: $SDK_EXPORT_DIR"