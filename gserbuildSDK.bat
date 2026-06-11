@echo OFF 
@REM set projectDir=D:\git\oxi\OXiScan\
@REM set buildDir=%projectDir%


@echo OFF 
setlocal enabledelayedexpansion

:: --- 1. 配置区域 (保持简洁) ---
set baseDir=%~dp0
set "projectDir=%baseDir%oxiscansdk\"
set "libName=FAP"
set buildDir=%baseDir%build\
set windemo_dir=%baseDir%\winSimpleCode
set androidDemo_dir=%baseDir%\ScannerSimple
set tgAndroid=%baseDir%\ScannerSimple\libFAP\src\main\cpp

set APIPath=%projectDir%base\export\OXiScan_Api.h
set APIErrPath=%projectDir%base\include\OXiScan_err.h
set APIDefPath=%projectDir%base\include\OXiScan_def.h


:: 路径配置
set "winX86=%buildDir%cmake-build-release-vs2019_x86"
set "winX64=%buildDir%cmake-build-release-vs2019_x64"
set "armv8=%buildDir%cmake-build-release-arm64-v8a"
set "armv7=%buildDir%cmake-build-release-armeabi-v7a"


:: 工具路径 (建议提取为外部配置文件或环境变量，这里保持你的路径)
set cmake=D:\apps\CMake\bin\cmake.exe
set ninja="D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
set "toolchain=D:/apps/Android/Sdk/ndk/25.2.9519653/build/cmake/android.toolchain.cmake"
set msbuild="D:\apps\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe"
set "androidParam=-DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_PLATFORM=android-28 -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja"





IF not EXIST "%buildDir%" (
    mkdir %buildDir%
)


if "%2"=="" (
   
    call ::genAndroid
    call ::genWin
 
    call ::copyWin
    call ::copyAndroid

    call ::genAndroidDemo
    call ::genWinDemo

	GOTO END

)

if %2 EQU 1 (
    call ::genX64
    call ::genX86
    @REM call :copyWin 
	GOTO END
)

if %2 EQU 2 (
    call ::genAndroid
    @REM call :copyAndroid 
	GOTO END
)

GOTO END


:genAndroid
for %%A in (armeabi-v7a arm64-v8a) do (
    %cmake%  %androidParam% -DANDROID_ABI=%%A -S %projectDir% -B %buildDir%cmake-build-release-%%A
    if !errorlevel! neq 0 exit /b 1

    %cmake%  --build %buildDir%cmake-build-release-%%A --target FAP -j 14
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
    %cmake% -G "Visual Studio 16 2019" -A !arch! -S !projectDir! -B !buildPath!
    if !errorlevel! neq 0 exit /b 1
    %cmake% --build !buildPath! --target !libName! --config Release -j 14
    if !errorlevel! neq 0 exit /b 1
)
goto :eof


:copyHeard
for %%A in ( %APIPath%  %APIErrPath%  %APIDefPath%) do (
     call ::copyAction %%A %1 
)

goto :eof


:copyAction
xcopy /y /i %1 %2
if %errorlevel% neq 0 (echo [ERROR] Failed to copy %1 & pause & exit /b 1)
goto :eof

:copyWin
    echo "copy win"
    call ::copyHeard %windemo_dir%
 
    call ::copyAction %winX86%\Release\%libName%.lib %windemo_dir%\libx86 
    call ::copyAction %winX86%\Release\%libName%.dll %windemo_dir%\Release	

    call ::copyAction %winX64%\Release\%libName%.lib %windemo_dir%\libx64 
    call ::copyAction %winX64%\Release\%libName%.dll %windemo_dir%\x64\Release

goto:eof



:copyAndroid
    echo "copy android"    

    call ::copyHeard %tgAndroid%\include
    call ::copyAction %armv7%\lib%libName%.so %tgAndroid%\armeabi-v7a
    call ::copyAction %armv8%\lib%libName%.so %tgAndroid%\arm64-v8a 

goto:eof

:genAndroidDemo

    cd %androidDemo_dir%
    call gradlew.bat assembleDebug
    cd %baseDir%

goto:eof


:genWinDemo

%msbuild% "%windemo_dir%\GSerLibWin.sln" /p:Configuration=Release /p:Platform=x64
%msbuild% "%windemo_dir%\GSerLibWin.sln" /p:Configuration=Release /p:Platform=x86

goto:eof

:END