@echo OFF 
set projectDir=D:\git\oxi\g6\FAP6010_win7
set buildDir="D:\output\build"


set winX86=%buildDir%\cmake-build-release_x86
set winX64=%buildDir%\cmake-build-release_x64

set armv8=%buildDir%\cmake-build-release_armv8
set armv7=%buildDir%\cmake-build-release_armv7


set cmake=D:\apps\CMake\bin\cmake.exe
set ninja="D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
set "toolchain=D:/apps/Android/Sdk/ndk/25.2.9519653/build/cmake/android.toolchain.cmake"

set "androidParam=-DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DCMAKE_SYSTEM_VERSION=21 -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja"

call ::genArmv7
call ::genArmv8
call ::genX64
call ::genX86

GOTO END

:genArmv8
IF EXIST "%armv8%" (
    rd /S /Q  %armv8%
)

%cmake%  %androidParam% -DANDROID_ABI=arm64-v8a -S %projectDir% -B %armv8%
IF %errorlevel% neq 0 (
    echo fail to generate android v8a cmake project
    pause
    GOTO END
)

%cmake%  --build %armv8% --target FAP60 -j 14
IF %errorlevel% neq 0 (
    echo fail to build android v8a cmake project
    pause
    GOTO END
)
goto:eof



:genArmv7

IF EXIST "%armv7%" (
    rd /S /Q  %armv7%
)

%cmake%  %androidParam% -DANDROID_ABI=armeabi-v7a -S %projectDir% -B %armv7%
IF %errorlevel% neq 0 (
    echo fail to generate android v8a cmake project
    pause
    GOTO END
)

%cmake%  --build %armv7% --target FAP60 -j 14
IF %errorlevel% neq 0 (
    echo fail to build android v8a cmake project
    pause
    GOTO END
)
goto:eof


:genX86
echo "----------------create Win x86 cmake project-----------------------"
IF EXIST "%winX86%" (
    rd /S /Q  %winX86%
)
%cmake% -G "Visual Studio 16 2019" -A Win32 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10.0 -S %projectDir% -B %winX86%
IF %errorlevel% neq 0 (
    echo fail to generate Win x86 cmake project
    pause
    GOTO END
)
echo "----------------build Win x86 lib-----------------------"
%cmake% --build %winX86% --target FAP60 --config Release -j 14
IF %errorlevel% neq 0 (
    echo fail to generate Win x86 dll
    pause
    GOTO END
)
goto:eof

:genX64
echo "----------------create Win x64 cmake project-----------------------"
IF EXIST "%winX64%" (
    rd /S /Q  %winX64%
)

%cmake% -G "Visual Studio 16 2019" -A x64 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10.0 -S %projectDir% -B %winX64%
IF %errorlevel% neq 0 (
    echo fail to generate Win x64 cmake project
    pause
    GOTO END
)
echo "----------------build Win x64 lib-----------------------"
%cmake% --build %winX64% --target FAP60 --config Release -j 14
IF %errorlevel% neq 0 (
    echo fail to generate Win x64 dll
    pause
    GOTO END
)
goto:eof

:END