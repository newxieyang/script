#!/bin/bash
set -e

# ===================== 配置项（根据你的实际路径修改）=====================
# OpenCV 源码根目录
PROJECT_DIR="/data/usershare/git/opencv-4.2.0"
# 编译输出目录
BUILD_DIR="${PROJECT_DIR}/build"
# 编译线程数（默认使用全部CPU核心）
JOBS=$(nproc)
# ======================================================================

echo "===== 1. 预处理：注释所有强制下载逻辑，彻底禁止网络下载 ====="
# 注释所有 ocv_download 下载语句，根治 IPPICV/ADE 等下载
find "${PROJECT_DIR}" -name "*.cmake" -type f -exec sed -i 's/^ocv_download/#ocv_download/g' {} \;

echo "===== 2. 清理旧编译缓存 ====="
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "===== 3. CMake 配置（仅保留指定模块 + 全量禁用附加组件） ====="
cmake -G "Unix Makefiles" -S "${PROJECT_DIR}" -B "${BUILD_DIR}" \
-DBUILD_DOCS=OFF \
-DBUILD_SHARED_LIBS=ON \
-DBUILD_opencv_world=ON \
-DBUILD_opencv_highgui=ON \
-DBUILD_opencv_core=ON \
-DBUILD_opencv_imgproc=ON \
-DBUILD_opencv_imgcodecs=ON \
# 关闭所有无关模块
-DBUILD_FAT_JAVA_LIB=OFF \
-DBUILD_TESTS=OFF \
-DBUILD_opencv_apps=OFF \
-DBUILD_opencv_calib3d=OFF \
-DBUILD_opencv_contrib=OFF \
-DBUILD_opencv_features2d=OFF \
-DBUILD_opencv_flann=OFF \
-DBUILD_opencv_gpu=OFF \
-DBUILD_opencv_java=OFF \
-DBUILD_opencv_legacy=OFF \
-DBUILD_opencv_ml=OFF \
-DBUILD_opencv_nonfree=OFF \
-DBUILD_opencv_dnn=OFF \
-DBUILD_opencv_objdetect=OFF \
-DBUILD_opencv_ocl=OFF \
-DBUILD_opencv_photo=OFF \
-DBUILD_opencv_python=OFF \
-DBUILD_opencv_stitching=OFF \
-DBUILD_opencv_superres=OFF \
-DBUILD_opencv_gapi=OFF \
-DBUILD_opencv_ts=OFF \
-DBUILD_opencv_video=OFF \
-DBUILD_opencv_videostab=OFF \
# 关闭第三方图像编解码库（不依赖系统外部库）
-DBUILD_TIFF=OFF \
-DBUILD_JASPER=OFF \
-DBUILD_JPEG=OFF \
-DBUILD_OPENEXR=OFF \
-DBUILD_PNG=OFF \
-DBUILD_ZLIB=OFF \
-DBUILD_WEBP=OFF \
-DBUILD_ITT=OFF \
# 关闭硬件/多媒体组件
-DWITH_1394=OFF \
-DWITH_EIGEN=OFF \
-DWITH_FFMPEG=OFF \
-DWITH_GIGEAPI=OFF \
-DWITH_GSTREAMER=OFF \
-DWITH_GTK=OFF \
-DWITH_PVAPI=OFF \
-DWITH_V4L=OFF \
-DWITH_LIBV4L=OFF \
-DWITH_CUDA=OFF \
-DWITH_CUFFT=OFF \
-DWITH_OPENCL=OFF \
-DWITH_OPENCLAMDBLAS=OFF \
-DWITH_OPENCLAMDFFT=OFF \
# 彻底禁用 IPP / IPPICV / ADE 与外部下载
-DWITH_IPP=OFF \
-DWITH_IPPICV=OFF \
-DBUILD_IPP_IW=OFF \
-DWITH_ADE=OFF \
-DDOWNLOAD_EXTERNALS=OFF \
-DOPENCV_DOWNLOAD_PATH=/dev/null \
-DCMAKE_DISABLE_FIND_PACKAGE_ADE=ON \
-DCMAKE_DISABLE_FIND_PACKAGE_IPPICV=ON

echo "===== 4. 开始编译 (线程数: ${JOBS}) ====="
make -C "${BUILD_DIR}" -j${JOBS}


echo "============================================="
echo "编译安装完成！"
echo "已编译模块: core imgproc imgcodecs highgui opencv_world"
echo "动态库默认安装路径: ${BUILD_DIR}"
echo "头文件默认安装路径: /usr/local/include"
echo "============================================="
