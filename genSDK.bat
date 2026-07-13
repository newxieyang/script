@echo OFF
setlocal enabledelayedexpansion

:: --- 1. 配置区域 (保持简洁) ---
set "baseDir=%~dp0"
set "projectDir=%baseDir%oxiscansdk\"
set "libName=FAP"

:: 路径配置
set "winX86=%projectDir%cmake-build-release-vs2019_x86"
set "winX64=%projectDir%cmake-build-release-vs2019_x64"
set "armv8=%projectDir%cmake-build-release-arm64-v8a"
set "armv7=%projectDir%cmake-build-release-armeabi-v7a"

:: 工具路径 (建议提取为外部配置文件或环境变量，这里保持你的路径)
set "cmake=D:\apps\CMake\bin\cmake.exe"
set "ninja=D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
set "toolchain=D:/apps/Android/Sdk/ndk/25.2.9519653/build/cmake/android.toolchain.cmake"
set "msbuild=D:\apps\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe"
set "strip=D:\apps\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe "

set "androidParam=-DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_PLATFORM=android-28 -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja"

:: --- 2. 逻辑分发 ---
if "%~2"=="" (
    call :buildAll
) else if "%~2"=="1" (
    call :genWin
) else if "%~2"=="2" (
    call :genAndroid
)
goto :END

:: --- 3. 核心功能模块 ---

:buildAll
call :genAndroid
call :genWin
call :copyFiles
call :genDemos
goto :eof

:genAndroid
echo [INFO] Generating Android targets...
for %%A in (armeabi-v7a arm64-v8a) do (
    set "buildPath=!projectDir!cmake-build-release-%%A"
    if exist "!buildPath!" rd /s /q "!buildPath!"
    %cmake% %androidParam% -DANDROID_ABI=%%A -S "%projectDir%" -B "!buildPath!"
    if !errorlevel! neq 0 exit /b 1
    %cmake% --build "!buildPath!" --target %libName% -j 14
    if !errorlevel! neq 0 exit /b 1
    %strip% --strip-unneeded --strip-debug !buildPath!/lib%libName%.so 
)
goto :eof

:genWin
echo [INFO] Generating Windows targets...
for %%A in (x86 x64) do (
    set "arch=Win32"
    if "%%A"=="x64" set "arch=x64"
    set buildPath=%projectDir%cmake-build-release-vs2019_%%A
    echo !buildPath!
    %cmake% -G "Visual Studio 16 2019" -A !arch! -S !projectDir! -B !buildPath!
    if !errorlevel! neq 0 exit /b 1
    %cmake% --build !buildPath! --target !libName! --config Release -j 14
    if !errorlevel! neq 0 exit /b 1
)
goto :eof

:copyFiles
echo [INFO] Copying library files...
:: 使用统一的函数减少重复
call :copyAction "%projectDir%base\export\OXiScan_Api.h" "%baseDir%winSimpleCode\"
:: ... (同理处理其他文件)
goto :eof

:copyAction
xcopy /y /i %1 %2
if %errorlevel% neq 0 (echo [ERROR] Failed to copy %1 & pause & exit /b 1)
goto :eof

:genDemos
:: 简化 Gradlew 和 MSBuild 调用
pushd "%baseDir%ScannerSimple" && call gradlew.bat assembleDebug && popd
%msbuild% "%baseDir%winSimpleCode\GSerLibWin.sln" /p:Configuration=Release /p:Platform=x64
%msbuild% "%baseDir%winSimpleCode\GSerLibWin.sln" /p:Configuration=Release /p:Platform=x86
goto :eof

:END
echo [INFO] Build Finished.
pause