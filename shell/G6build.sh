#!/bin/bash
# ================================================
# 编译 G6SDK 动态库 - 极简版
# ================================================
set -e  # 遇到错误立即退出
PROJECT_DIR="/data/usershare/git/A910/"          # 可改为 $HOME/opencv （无需sudo）
BUILD_DIR="$PROJECT_DIR/A910/build"
NUM_JOBS=$(nproc --all)             # 使用全部CPU核心，内存不够可改成 4 或 6
echo "=== 步骤2: 创建构建目录 ==="
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

echo "=== 步骤3: CMake 配置（极简 + 动态库 + opencv_world）==="
cmake -G "Unix Makefiles" -S "${PROJECT_DIR}" -B "${BUILD_DIR}"

echo "=== 步骤4: 开始编译（${NUM_JOBS} 线程）==="
make -C "${BUILD_DIR}" -j${JOBS}




