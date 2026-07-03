@echo OFF
setlocal enabledelayedexpansion

:: --- 1. 配置区域 ---
set "projectDir=E:\3rdSRC\opencv-4.12.0"
set "libName=opencv_world" 
:: 注意：若开启了 BUILD_opencv_world，目标通常是 opencv_world

:: 路径配置
set "winX86=%projectDir%cmake-build-release-vs2019_x86"
set "winX64=%projectDir%cmake-build-release-vs2019_x64"
set "armv8=%projectDir%cmake-build-release-arm64-v8a"
set "armv7=%projectDir%cmake-build-release-armeabi-v7a"

set "cmake=D:\apps\CMake\bin\cmake.exe"
set "ninja=D:/apps/CMake/bin/ninja.exe"
set "toolchain=D:/apps/Android/Sdk/ndk/28.2.13676358/build/cmake/android.toolchain.cmake"
set "androidSdk=D:\apps\Android\Sdk"

:: OpenCV 核心参数：开启 world 模式、Java 接口、关闭多余模块
set "opencvParams=-DBUILD_opencv_world=ON -DBUILD_JAVA=ON -DBUILD_SHARED_LIBS=ON -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_opencv_apps=OFF -DWITH_OPENMP=OFF -DWITH_TBB=OFF -DWITH_IPP=OFF"
set "androidParam=%opencvParams% -DANDROID_SDK=%androidSdk% -DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_PLATFORM=android-29 -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja -DCMAKE_THREAD_LIBS_INIT= -DCMAKE_HAVE_PTHREAD_H=ON -DCMAKE_USE_PTHREADS_INIT=ON -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_HAVE_IO_H=OFF "

:: --- 2. 逻辑分发 ---
call :genAndroid
goto :END

:genAndroid
echo [INFO] Generating Android targets...
for %%A in (arm64-v8a armeabi-v7a) do (
    set "buildPath=%projectDir%\cmake-build-release-%%A"
    if exist "!buildPath!" rd /s /q "!buildPath!"
    
    echo [EXEC] Configuring %%A...
    %cmake% %androidParam% -DANDROID_ABI=%%A -S "%projectDir%" -B "!buildPath!"
    if !errorlevel! neq 0 exit /b 1
    
    echo [EXEC] Building %%A...
    %cmake% --build "!buildPath!" --target %libName% -j 14
)
goto :eof

:genWin
:: ... Windows 逻辑保持不变，但建议检查 -DANDROID 相关参数在 Windows 编译中应去掉 ...
goto :eof

:END




:END
echo [INFO] Build Finished.
pause