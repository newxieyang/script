@echo OFF 
set projectDir=D:\git\oxi\g6\FAP6010_win7


set winX86=%projectDir%\cmake-build-release_x86
set winX64=%projectDir%\cmake-build-release_x64



@REM set armv8=%projectDir%\cmake-build-release_armv8
@REM set armv7=%projectDir%\cmake-build-release_armv7

@REM set cmake="D:\apps\JetBrains\CLion 2023.1.4\bin\cmake\win\x64\bin\cmake.exe"
@REM set win64C="-DCMAKE_C_COMPILER=D:/apps/Microsoft Visual Studio/2019/Professional/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x64/cl.exe"
@REM set win64CXX="-DCMAKE_CXX_COMPILER=D:/apps/Microsoft Visual Studio/2019/Professional/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x64/cl.exe"
@REM set win86C="-DCMAKE_C_COMPILER=D:/apps/Microsoft Visual Studio/2019/Professional/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x86/cl.exe"
@REM set win86CXX="-DCMAKE_CXX_COMPILER=D:/apps/Microsoft Visual Studio/2019/Professional/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x86/cl.exe"

set cmake="D:\apps\CMake\bin\cmake.exe"

set ninja="D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"




echo "----------------create Win x64 cmake project-----------------------"
%cmake% -G "Visual Studio 16 2019" -A x64 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10.0 -S %projectDir% -B %winX64%
IF %errorlevel% neq 0 (
    echo fail to generate Win x64 cmake project
    pause
    GOTO END
)
echo "----------------build Win x64 lib-----------------------"
%cmake% --build %winX64% --target FAP60 --config Release
IF %errorlevel% neq 0 (
    echo fail to generate Win x64 dll
    pause
    GOTO END
)


echo "----------------create Win x86 cmake project-----------------------"
%cmake% -G "Visual Studio 16 2019" -A Win32 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10.0 -S %projectDir% -B %winX86%
IF %errorlevel% neq 0 (
    echo fail to generate Win x86 cmake project
    pause
    GOTO END
)
echo "----------------build Win x86 lib-----------------------"
%cmake% --build %winX86% --target FAP60 --config Release
IF %errorlevel% neq 0 (
    echo fail to generate Win x86 dll
    pause
    GOTO END
)


@REM xcopy %projectDir%\include\OXiScanAPI.h %winDemoDir% /y
@REM xcopy %projectDir%\include\OXiScanUltimate.h %winDemoDir% /y
@REM xcopy %projectDir%\include\OXiScanUltimateApi_err.h %winDemoDir% /y


@REM xcopy %winX86%\Release\FAP60.lib %winDemoDir%\libx86	/y
@REM xcopy %winX86%\Release\FAP60.dll %winDemoDir%\Release	/y


@REM xcopy %winX64%\Release\FAP60.lib %winDemoDir%\libx64 /y
@REM xcopy %winX64%\Release\FAP60.dll %winDemoDir%\x64\Release /y


@REM xcopy %armv7%\libFAP60.so %androidDemoDir%\armeabi-v7a /y
@REM xcopy %armv8%\libFAP60.so %androidDemoDir%\arm64-v8a /y

@REM xcopy %projectDir%\include\OXiScanAPI.h %androidDemoDir%\include /y
@REM xcopy %projectDir%\include\OXiScanUltimate.h %androidDemoDir%\include /y
@REM xcopy %projectDir%\include\OXiScanUltimateApi_err.h %androidDemoDir%\include /y


:END