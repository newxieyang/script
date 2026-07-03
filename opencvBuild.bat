
@echo OFF 
setlocal enabledelayedexpansion

set "projectDir=E:\3rdSRC\opencv-4.10.0"
set "buildDir=%projectDir%\"


: 核心精简配置参数 (Android 和 Windows 通用)
set "slimConfig= -DBUILD_LIST=core,imgproc,calib3d,world ^
-DBUILD_SHARED_LIBS=ON ^
-DBUILD_PERF_TESTS=OFF ^
-DBUILD_opencv_apps=OFF ^
-DBUILD_JAVA=OFF ^
-DWITH_OPENNI2=OFF ^
-DWITH_OPENVINO=OFF ^
-DWITH_OPENVX=OFF ^
-DWITH_PLAIDML=OFF ^
-DWITH_PROTOBUF=OFF ^
-DWITH_PVAPI=OFF ^
-DWITH_QT=OFF ^
-DWITH_QUIRC=OFF ^
-DWITH_SPNG=OFF ^
-DWITH_TBB=OFF ^
-DWITH_TIMVX=OFF ^
-DWITH_UEYE=OFF ^
-DWITH_VTK=OFF ^
-DWITH_VULKAN=OFF ^
-DWITH_WEBNN=OFF ^
-DWITH_WIN32UI=OFF ^
-DWITH_XIMEA=OFF ^
-DWITH_ZLIB_NG=OFF ^
-Dccit=OFF ^
-Dlogluv=OFF ^
-Dlzw=OFF ^
-Dmdi=OFF ^
-Dnext=OFF ^
-Dold-jpeg=OFF ^
-Dpackbits=OFF ^
-Dthunder=OFF ^
-DWITH_HPX=OFF ^
-DWITH_IPP=OFF ^
-DWITH_ITT=OFF ^
-DWITH_JASPER=OFF ^
-DWITH_JPEGXL=OFF ^
-DWITH_LAPACK=OFF ^
-DWITH_LIBREALSENSE=OFF ^
-DWITH_MFX=OFF ^
-DWITH_MSMF=OFF ^
-DWITH_MSMF_DXVA=OFF ^
-DWITH_OAK=OFF ^
-DWITH_OBSENSOR=OFF ^
-DWITH_ONNX=OFF ^
-DWITH_OPENCL=OFF ^
-DWITH_OPENCLAMDBLAS=OFF ^
-DWITH_OPENCLAMDFFT=OFF ^
-DWITH_OPENCL_D3D11_NV=OFF ^
-DWITH_OPENCL_SVM=OFF ^
-DWITH_OPENEVR=OFF ^
-DWITH_OPENGL=OFF ^
-DWITH_OPENMP=OFF ^
-DWITH_OPENNI=OFF ^
-DWITH_1394=OFF ^
-DWITH_ARITH_DEC=OFF ^
-DWITH_ARITH_ENC=OFF ^
-DWITH_DIRECTML=OFF ^
-DWITH_DSHOW=OFF ^
-DWITH_EIGEN=OFF ^
-DWITH_FFMPEG=OFF ^
-DWITH_FREETYPE=OFF ^
-DWITH_GSTREAMER=OFF ^
-DWITH_CANN=OFF ^
-DWITH_CLP=OFF ^
-DWITH_CUDA=OFF ^
-DWITH_DIRECTX=OFF ^
-DWITH_GDAL=OFF ^
-DWITH_GDCM=OFF ^
-DWITH_HALIDE=OFF ^
-DOPENCV_DNN_CUDA=OFF ^
-DOPENCV_DNN_OPENCL=OFF ^
-DOPENCV_DNN_OPENVINO=OFF ^
-DOPENCV_DNN_PERF_CAFFE=OFF ^
-DOPENCV_TEST_DNN_CANN=OFF ^
-DOPENCV_TEST_DNN_OPENVINO=OFF ^
-DOPENCV_TEST_DNN_TFLITE=OFF ^
-DOPENCV_TEST_DNN_TIMVX=OFF ^
-DBUILD_opencv_java=OFF ^
-DBUILD_opencv_js=OFF DWITH_V4L=OFF ^
-DBUILD_opencv_stitching=OFF ^
-DBUILD_TESTS=OFF ^
-DBUILD_PERF_TESTS=OFF ^
-DBUILD_DOCS=OFF ^
-DBUILD_JPEG=OFF ^
-DBUILD_PNG=OFF ^
-DBUILD_WEBP=OFF ^
-DBUILD_TIFF=OFF ^
-DBUILD_OPENJPEG=OFF ^
-DBUILD_OPENEXR=OFF ^
-DWITH_ZLIB=OFF ^
-DWITH_JPEG=OFF ^
-DWITH_PNG=OFF ^
-DWITH_WEBP=OFF ^
-DWITH_TIFF=OFF ^
-DWITH_OPENJPEG=OFF ^
-DWITH_OPENEXR=OFF ^
-DWITH_IMGCODEC_HDR=OFF ^
-DWITH_IMGCODEC_PFM=OFF ^
-DWITH_IMGCODEC_PXM=OFF ^
-DWITH_IMGCODEC_SUNRASTER=OFF ^
-DWITH_IMGCODEC_GIF=OFF ^
-DBUILD_PYTHON3=OFF ^
-DCMAKE_BUILD_TYPE=Release ^
-DENABLE_INTRINSICS=OFF ^
-DOPENCV_MSVC_PARALLEL=OFF ^
-DINSTALL_C_EXAMPLES=OFF ^
-DINSTALL_PDB=OFF ^
-DINSTALL_TESTS=OFF ^
-DPROTOBUF_UPDATE_FILES=OFF ^
-DWITH_DYNAMIC_IPP=OFF ^
-DWITH_STATIC_CRT=OFF -DWITH_IPP_IW=OFF"

:: 路径配置
set "winX86=%projectDir%cmake-build-release-vs2019_x86"
set "winX64=%projectDir%cmake-build-release-vs2019_x64"
set "armv8=%projectDir%cmake-build-release-arm64-v8a"
set "armv7=%projectDir%cmake-build-release-armeabi-v7a"

:: 工具路径 (建议提取为外部配置文件或环境变量，这里保持你的路径)
set cmake=D:\apps\CMake\bin\cmake.exe
set ninja="D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
set "toolchain=D:/apps/Android/Sdk/ndk/28.2.13676358/build/cmake/android.toolchain.cmake"
set msbuild="D:\apps\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe"
set "androidParam=-DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_PLATFORM=android-28 -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja %slimConfig%"

@REM set "androidParam=-DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_PLATFORM=android-28 ^
@REM   -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja ^
@REM   -DBUILD_LIST=core,imgproc,imgcodecs,calib3d -DBUILD_opencv_world=ON ^
@REM   -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_opencv_apps=OFF ^
@REM   -DWITH_IPP=OFF -DWITH_FFMPEG=OFF -DWITH_OPENEXR=OFF -DWITH_WEBP=OFF -DWITH_PROTOBUF=OFF -DWITH_IPP_IW=OFF^
@REM   -DCPU_BASELINE=NEON -DOPENCV_GENERATE_SETUPVARS=OFF -DOPENCV_ICV_PACKAGE_DOWNLOAD_URL= """

IF EXIST "%buildDir%cmake-build-release-armeabi-v7a" (rm %buildDir%cmake-build-release-armeabi-v7a)


if "%2"=="" (
@REM    call ::genAndroid
    @REM call ::genWin

     %cmake%  %androidParam% -DANDROID_ABI=armeabi-v7a  -S %projectDir% -B %buildDir%cmake-build-release-armeabi-v7a 
    if !errorlevel! neq 0 exit /b 1
	GOTO END
)

if %2 EQU 1 (
    call ::genWin
	GOTO END
)

if %2 EQU 2 (
    call ::genAndroid
	GOTO END
)

GOTO END


:genAndroid
for %%A in (armeabi-v7a arm64-v8a) do (
    %cmake%  %androidParam% -DANDROID_ABI=%%A -S %projectDir% -B %buildDir%cmake-build-release-%%A
    if !errorlevel! neq 0 exit /b 1

    @REM %cmake%  --build %buildDir%cmake-build-release-%%A  -j 14
    @REM if !errorlevel! neq 0 exit /b 1

)

goto :eof


:genWin
echo [INFO] Generating Windows targets...
for %%A in (x86 x64) do (
    set "arch=Win32"
    if "%%A"=="x64" set "arch=x64"
    set buildPath=%buildDir%cmake-build-release-vs2019_%%A
    echo !buildPath!
    %cmake% -G "Visual Studio 16 2019" -A !arch! %slimConfig% -S !projectDir! -B !buildPath!
    if !errorlevel! neq 0 exit /b 1
    %cmake% --build !buildPath!  --config Release -j 14
    if !errorlevel! neq 0 exit /b 1
)
goto :eof

:END