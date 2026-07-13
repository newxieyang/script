
@echo OFF 
setlocal enabledelayedexpansion
call config.bat

set "projectDir=d:\\opencv4.12.0\\"
set buildDir=%projectDir%build\

:: 路径配置
set "winX86=%buildDir%cmake-build-release-vs2019_x86"
set "winX64=%buildDir%cmake-build-release-vs2019_x64"
set "armv8=%buildDir%cmake-build-release-arm64-v8a"
set "armv7=%buildDir%cmake-build-release-armeabi-v7a"



: 核心精简配置参数 (Android 和 Windows 通用)
set "slimConfig=-DBUILD_LIST=core,imgproc,imgcodecs,world -DBUILD_opencv_world=ON -DBUILD_SHARED_LIBS=ON -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOCS=OFF -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENEXR=OFF"

IF not EXIST "%buildDir%" (mkdir %buildDir%)


if "%2"=="" (
    call ::genAndroid
    call ::genWin
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

    %cmake%  --build %buildDir%cmake-build-release-%%A  -j 14
    if !errorlevel! neq 0 exit /b 1

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