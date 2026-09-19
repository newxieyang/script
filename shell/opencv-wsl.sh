#!/bin/bash

# ==============================================================================
# OpenCV 4.6.0 Build Script
#
# Build:
#   x64    -> Local GCC 9.3
#   ARM64  -> AArch64 GCC 9.3
#
# Final package:
#
#   opencv_release/
#   ├── x64/
#   │   └── lib/
#   │       └── libopencv_world.so
#   │
#   └── arm/
#       └── lib/
#           └── libopencv_world.so
#
# 特点：
#   1. BUILD_SHARED_LIBS=ON
#   2. BUILD_opencv_world=ON
#   3. 最终只保留 libopencv_world.so
#   4. libopencv_world.so 是真实 ELF 文件，不是软链接
#   5. 删除 .so.4.6 / .so.4.6.0 等版本文件
#   6. 修改 SONAME 为 libopencv_world.so
# ==============================================================================

set -e

# ==============================================================================
# 1. 路径配置
# ==============================================================================

OPENCV_SRC="/mnt/e/3rdSRC/opencv-4.6.0"

AARCH64_GCC_ROOT="/opt/aarch64-gcc9.3"
LOCAL_GCC_ROOT="/opt/gcc-9.3.0"

INSTALL_PREFIX="${OPENCV_SRC}/opencv_release"

BUILD_X64_DIR="${OPENCV_SRC}/build_x64"
BUILD_ARM_DIR="${OPENCV_SRC}/build_arm"

# ==============================================================================
# 2. OpenCV 模块
# ==============================================================================

BUILD_LIST="core,highgui,imgcodecs,imgproc,world"

# ==============================================================================
# 3. 检查工具
# ==============================================================================

command -v cmake >/dev/null 2>&1 || {
    echo "ERROR: cmake not found"
    exit 1
}

command -v make >/dev/null 2>&1 || {
    echo "ERROR: make not found"
    exit 1
}

command -v patchelf >/dev/null 2>&1 || {
    echo ""
    echo "ERROR: patchelf not found."
    echo ""
    echo "Please install:"
    echo "    sudo apt install patchelf"
    echo ""
    exit 1
}

# ==============================================================================
# 4. 检查 GCC
# ==============================================================================

if [ ! -x "$LOCAL_GCC_ROOT/bin/gcc" ]; then
    echo "ERROR: x64 GCC not found:"
    echo "    $LOCAL_GCC_ROOT/bin/gcc"
    exit 1
fi

if [ ! -x "$LOCAL_GCC_ROOT/bin/g++" ]; then
    echo "ERROR: x64 G++ not found:"
    echo "    $LOCAL_GCC_ROOT/bin/g++"
    exit 1
fi

if [ ! -x "$AARCH64_GCC_ROOT/bin/aarch64-linux-gnu-gcc" ]; then
    echo "ERROR: ARM64 GCC not found:"
    echo "    $AARCH64_GCC_ROOT/bin/aarch64-linux-gnu-gcc"
    exit 1
fi

if [ ! -x "$AARCH64_GCC_ROOT/bin/aarch64-linux-gnu-g++" ]; then
    echo "ERROR: ARM64 G++ not found:"
    echo "    $AARCH64_GCC_ROOT/bin/aarch64-linux-gnu-g++"
    exit 1
fi

# ==============================================================================
# 5. 通用 CMake 参数
# ==============================================================================

COMMON_FLAGS=(
    "-DBUILD_SHARED_LIBS=ON"
       "-DBUILD_opencv_world=ON"
       "-DCMAKE_BUILD_TYPE=Release"
       "-DBUILD_TESTS=OFF"
       "-DBUILD_PERF_TESTS=OFF"
       "-DBUILD_EXAMPLES=OFF"
       "-DBUILD_DOCS=OFF"
       "-DWITH_IPP=OFF"
       "-DBUILD_IPP_IW=OFF"

       "-DDOWNLOAD_EXTERNAL_TEST_DATA=OFF"

       "-DWITH_GTK=OFF"
       "-DWITH_QT=OFF"

       "-DWITH_TIFF=OFF"
       "-DWITH_JASPER=OFF"
       "-DWITH_OPENEXR=OFF"
       "-DWITH_WEBP=OFF"

       "-DWITH_OPENCL=OFF"
       "-DWITH_CUDA=OFF"

       # ------------------------------------------------------------------
       # 模块裁剪：只保留 core, imgproc, imgcodecs, videoio, highgui, world
       # ------------------------------------------------------------------
       "-DBUILD_opencv_calib3d=OFF"
       "-DBUILD_opencv_dnn=OFF"
       "-DBUILD_opencv_features2d=OFF"
       "-DBUILD_opencv_flann=OFF"
       "-DBUILD_opencv_gapi=OFF"
       "-DBUILD_opencv_ml=OFF"
       "-DBUILD_opencv_objdetect=OFF"
       "-DBUILD_opencv_photo=OFF"
       "-DBUILD_opencv_stitching=OFF"
       "-DBUILD_opencv_video=OFF"

       # ------------------------------------------------------------------
       # videoio: highgui 硬依赖，保留但关闭所有视频采集后端
       # ------------------------------------------------------------------
       "-DWITH_FFMPEG=OFF"
       "-DWITH_GSTREAMER=OFF"
       "-DWITH_V4L=OFF"
       "-DWITH_1394=OFF"
       "-DWITH_OPENNI=OFF"
       "-DWITH_OPENNI2=OFF"

       # ------------------------------------------------------------------
       # Python / Java 包装层
       # ------------------------------------------------------------------
       "-DBUILD_opencv_python2=OFF"
       "-DBUILD_opencv_python3=OFF"
       "-DBUILD_opencv_java=OFF"
       "-DBUILD_opencv_js=OFF"
)

# ==============================================================================
# 6. 清理历史目录
# ==============================================================================

echo ""
echo "=============================================================================="
echo ">>> Cleaning previous build..."
echo "=============================================================================="

rm -rf "$INSTALL_PREFIX"
rm -rf "$BUILD_X64_DIR"
rm -rf "$BUILD_ARM_DIR"

mkdir -p "$INSTALL_PREFIX/x64"
mkdir -p "$INSTALL_PREFIX/arm"

# ==============================================================================
# 7. 最终处理 OpenCV
# 最终：
#     libopencv_world.so
# 必须：
#     1. regular file
#     2. ELF
#     3. SONAME = libopencv_world.so
# 删除：
#     libopencv_world.so.4.6
#     libopencv_world.so.4.6.0
# ==============================================================================

finalize_opencv_world()
{
    local target_dir="$1"

    echo ""
    echo "=============================================================================="
    echo ">>> Finalizing OpenCV:"
    echo ">>> $target_dir"
    echo "=============================================================================="

    local lib_dir=""

    if [ -d "$target_dir/lib" ]; then
        lib_dir="$target_dir/lib"
    elif [ -d "$target_dir/lib64" ]; then
        lib_dir="$target_dir/lib64"
    else
        echo "ERROR: Cannot find lib directory:"
        echo "    $target_dir"
        return 1
    fi

    cd "$lib_dir"

    echo ">>> Library directory:"
    echo "    $lib_dir"

    echo ""
    echo ">>> Installed OpenCV files:"
    ls -lah libopencv_world.so* 2>/dev/null || true

    # ==========================================================================
    # 找到真正的 OpenCV ELF 文件
    # ==========================================================================

    local real_so=""

    for f in \
        libopencv_world.so.4.6.0 \
        libopencv_world.so.4.6
    do
        if [ -f "$f" ] && [ ! -L "$f" ]; then

            if file "$f" | grep -q "ELF"; then
                real_so="$f"
                break
            fi

        fi
    done

    if [ -z "$real_so" ]; then
        echo ""
        echo "ERROR: Real OpenCV world ELF library not found!"

        echo ""
        echo "Current files:"
        ls -lah libopencv_world.so* 2>/dev/null || true

        cd - >/dev/null
        return 1
    fi

    echo ""
    echo ">>> Real library:"
    echo "    $real_so"

    # ==========================================================================
    # 检查 ELF 架构
    # ==========================================================================

    echo ""
    echo ">>> ELF information:"
    file "$real_so"

    # ==========================================================================
    # 临时保存真实 ELF
    # 不能直接：
    #     cp real.so libopencv_world.so
    # 因为 libopencv_world.so 可能已经是软链接。
    # 所以先复制到临时文件。
    # ==========================================================================

    local tmp_so
    tmp_so="/tmp/libopencv_world.so.$$"

    cp -f "$real_so" "$tmp_so"

    echo ""
    echo ">>> Removing old OpenCV world files..."

    rm -f libopencv_world.so
    rm -f libopencv_world.so.*

    # ==========================================================================
    # 创建最终文件
    # ==========================================================================

    mv "$tmp_so" libopencv_world.so


    echo ""
    echo ">>> Setting SONAME..."

    patchelf --set-soname libopencv_world.so libopencv_world.so

    # ==========================================================================
    # 检查最终文件
    # ==========================================================================

    echo ""
    echo ">>> Final library:"
    ls -lah libopencv_world.so

    # 必须是普通文件
    if [ ! -f "libopencv_world.so" ]; then
        echo "ERROR: libopencv_world.so does not exist!"
        cd - >/dev/null
        return 1
    fi

    # 不能是软链接
    if [ -L "libopencv_world.so" ]; then
        echo "ERROR: libopencv_world.so is still a symlink!"
        ls -lah libopencv_world.so
        cd - >/dev/null
        return 1
    fi

    # 必须是 ELF
    if ! file libopencv_world.so | grep -q "ELF"; then
        echo "ERROR: libopencv_world.so is not ELF!"
        file libopencv_world.so
        cd - >/dev/null
        return 1
    fi

    # ==========================================================================
    # SONAME 检查
    # ==========================================================================

    echo ""
    echo ">>> SONAME:"
    readelf -d libopencv_world.so | grep SONAME || {
        echo "WARNING: SONAME not found!"
    }

    # ==========================================================================
    # 检查是否还有其他 world 文件
    # ==========================================================================

    echo ""
    echo ">>> Remaining OpenCV world files:"

    local remaining
    remaining=$(find . -maxdepth 1 -name "libopencv_world.so*" -print)

    echo "$remaining"

    # 必须只有 libopencv_world.so
    local count
    count=$(find . -maxdepth 1 -name "libopencv_world.so*" | wc -l)

    if [ "$count" -ne 1 ]; then
        echo ""
        echo "ERROR: More than one OpenCV world library remains!"
        cd - >/dev/null
        return 1
    fi

    # 检查没有软链接
    if find . -maxdepth 1 -type l -name "libopencv_world.so*" | grep -q .; then
        echo ""
        echo "ERROR: OpenCV world symlink still exists!"
        find . -maxdepth 1 -type l -name "libopencv_world.so*"
        cd - >/dev/null
        return 1
    fi

    echo ""
    echo ">>> OpenCV world finalize OK."

    cd - >/dev/null
}

# ==============================================================================
# 8. 构建 x64
# ==============================================================================

echo ""
echo "=============================================================================="
echo ">>> Starting x64 build..."
echo "=============================================================================="

mkdir -p "$BUILD_X64_DIR"
cd "$BUILD_X64_DIR"

cmake "$OPENCV_SRC" \
    -DCMAKE_C_COMPILER="$LOCAL_GCC_ROOT/bin/gcc" \
    -DCMAKE_CXX_COMPILER="$LOCAL_GCC_ROOT/bin/g++" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX/x64" \
    "${COMMON_FLAGS[@]}"

make -j"$(nproc)"

make install

cd ..

finalize_opencv_world "$INSTALL_PREFIX/x64"

# ==============================================================================
# 9. 构建 ARM64
# ==============================================================================

echo ""
echo "=============================================================================="
echo ">>> Starting ARM64 build..."
echo "=============================================================================="

mkdir -p "$BUILD_ARM_DIR"
cd "$BUILD_ARM_DIR"

# ==============================================================================
# ARM64 Toolchain
# ==============================================================================

cat > aarch64.toolchain.cmake <<EOF

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER
    $AARCH64_GCC_ROOT/bin/aarch64-linux-gnu-gcc
)

set(CMAKE_CXX_COMPILER
    $AARCH64_GCC_ROOT/bin/aarch64-linux-gnu-g++
)

set(CMAKE_FIND_ROOT_PATH
    $AARCH64_GCC_ROOT/aarch64-linux-gnu/libc
)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

EOF

echo ""
echo ">>> ARM64 toolchain:"
cat aarch64.toolchain.cmake

cmake "$OPENCV_SRC" \
    -DCMAKE_TOOLCHAIN_FILE="$BUILD_ARM_DIR/aarch64.toolchain.cmake" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX/arm" \
    "${COMMON_FLAGS[@]}"

make -j"$(nproc)"

make install

cd ..

finalize_opencv_world "$INSTALL_PREFIX/arm"

# ==============================================================================
# 10. 最终检查
# ==============================================================================

echo ""
echo ""
echo "=============================================================================="
echo ">>> FINAL PACKAGE CHECK"
echo "=============================================================================="

echo ""
echo ">>> x64:"
ls -lah "$INSTALL_PREFIX/x64/lib/" 2>/dev/null || true

echo ""
echo ">>> ARM64:"
ls -lah "$INSTALL_PREFIX/arm/lib/" 2>/dev/null || true

# ==============================================================================
# 检查 x64
# ==============================================================================

X64_SO="$INSTALL_PREFIX/x64/lib/libopencv_world.so"

if [ ! -f "$X64_SO" ]; then
    echo "ERROR: x64 libopencv_world.so missing!"
    exit 1
fi

if [ -L "$X64_SO" ]; then
    echo "ERROR: x64 libopencv_world.so is symlink!"
    exit 1
fi

# ==============================================================================
# 检查 ARM64
# ==============================================================================

ARM_SO="$INSTALL_PREFIX/arm/lib/libopencv_world.so"

if [ ! -f "$ARM_SO" ]; then
    echo "ERROR: ARM64 libopencv_world.so missing!"
    exit 1
fi

if [ -L "$ARM_SO" ]; then
    echo "ERROR: ARM64 libopencv_world.so is symlink!"
    exit 1
fi

# ==============================================================================
# 架构检查
# ==============================================================================

echo ""
echo "=============================================================================="
echo ">>> x64 ELF:"
echo "=============================================================================="

file "$X64_SO"

echo ""
echo "=============================================================================="
echo ">>> ARM64 ELF:"
echo "=============================================================================="

file "$ARM_SO"

echo ""
echo "=============================================================================="
echo ">>> x64 SONAME:"
echo "=============================================================================="

readelf -d "$X64_SO" | grep SONAME || true

echo ""
echo "=============================================================================="
echo ">>> ARM64 SONAME:"
echo "=============================================================================="

readelf -d "$ARM_SO" | grep SONAME || true

# ==============================================================================
# 最终输出
# ==============================================================================

echo ""
echo "=============================================================================="
echo ">>> BUILD SUCCESS"
echo "=============================================================================="

echo ""
echo "Output:"
echo ""
echo "  x64:"
echo "    $X64_SO"
echo ""
echo "  ARM64:"
echo "    $ARM_SO"
echo ""

echo "Final package contains only:"
echo ""
echo "  libopencv_world.so"
echo ""

echo "No:"
echo "  libopencv_world.so.4.6"
echo "  libopencv_world.so.4.6.0"
echo "  symlink"
echo ""

echo "=============================================================================="