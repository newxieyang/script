@echo OFF 
set projectDir=D:\git\oxi\OXiScan\
set buildDir=%projectDir%


set winX86=%buildDir%\cmake-build-release-vs2019_x86
set winX64=%buildDir%\cmake-build-release-vs2019_x64

set armv8=%buildDir%\cmake-build-release-arm64-v8a
set armv7=%buildDir%\cmake-build-release-armeabi-v7a

set cmake=D:\apps\CMake\bin\cmake.exe
set ninja="D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
set "toolchain=D:/apps/Android/Sdk/ndk/25.2.9519653/build/cmake/android.toolchain.cmake"

set "androidParam=-DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_PLATFORM=android-28 -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja"

set APIPath=%projectDir%base\export\OXiScan_Api.h
set APIErrPath=%projectDir%base\include\OXiScan_err.h
set APIDefPath=%projectDir%base\include\OXiScan_def.h

set libName="FAP"
set tgWin="D:\git\oxi\GSerWin"
set tgAndroid="D:\git\oxi\GSerAndroid\libFAP\src\main\cpp"


if "%2"=="" (
   
    call ::genArmv7
    call ::genArmv8

    call ::genX64
    call ::genX86
 
    call :copyWin
    call :copyAndroid

	GOTO END

)

if %2 EQU 1 (
    call ::genX64
    call ::genX86
    @REM call :copyWin 
	GOTO END
)

if %2 EQU 2 (
    call ::genArmv7
    call ::genArmv8
    @REM call :copyAndroid 
	GOTO END
)

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

%cmake%  --build %armv8% --target FAP -j 14
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

%cmake%  --build %armv7% --target FAP -j 14
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
%cmake% --build %winX86% --target FAP --config Release -j 14
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
%cmake% --build %winX64% --target FAP --config Release -j 14
IF %errorlevel% neq 0 (
    echo fail to generate Win x64 dll
    pause
    GOTO END
)
goto:eof



:copyWin
    echo "copy win"
 
    xcopy %APIPath% %tgWin% /y
        IF %errorlevel% neq 0 (
        echo copy win  %APIPath% file fail
        pause
        GOTO END
    )

      xcopy %APIErrPath% %tgWin% /y
        IF %errorlevel% neq 0 (
        echo copy win %APIErrPath% file fail
        pause
        GOTO END
    )

    xcopy %APIDefPath% %tgWin% /y
        IF %errorlevel% neq 0 (
        echo copy win %APIDefPath% file fail
        pause
        GOTO END
    )


    rem copy win_x86  fap70\Release
    rem xcopy %vs86Dir\fap70\Release\%%ibName%.dll %targetDir%\libx86 /y
    echo %winX86%\Release\%libName%.lib
    xcopy %winX86%\Release\%libName%.lib %tgWin%\libx86	/y
        IF %errorlevel% neq 0 (
        echo copy win x86 lib file fail
        pause
        GOTO END
    )
    xcopy %winX86%\Release\%libName%.dll %tgWin%\Release	/y
        IF %errorlevel% neq 0 (
        echo copy win x86 dll file fail
        pause
        GOTO END
    )

    rem copy win_x64
    rem xcopy %vs64Dir%%libName%.dll %targetDir%\libx64 /y
    xcopy %winX64%\Release\%libName%.lib %tgWin%\libx64 /y
        IF %errorlevel% neq 0 (
        echo copy win x64 lib file fail
        pause
        GOTO END
    )
    xcopy %winX64%\Release\%libName%.dll %tgWin%\x64\Release /y
        IF %errorlevel% neq 0 (
        echo copy win x64 dll file fail
        pause
        GOTO END
    )

goto:eof



:copyAndroid
    echo "copy android"    
    echo %androidDir%
    echo %SDKDir%

  xcopy %APIPath% %tgAndroid%\include /y
        IF %errorlevel% neq 0 (
        echo copy win  %APIPath% file fail
        pause
        GOTO END
    )

      xcopy %APIErrPath% %tgAndroid%\include /y
        IF %errorlevel% neq 0 (
        echo copy win %APIErrPath% file fail
        pause
        GOTO END
    )

  xcopy %APIDefPath% %tgAndroid%\include /y
        IF %errorlevel% neq 0 (
        echo copy win %APIDefPath% file fail
        pause
        GOTO END
    )


    xcopy %armv8%\lib%libName%.so %tgAndroid%\armeabi-v7a /y
    IF %errorlevel% neq 0 (
        echo copy android v7a so  fail
        pause
        GOTO END
    )
    xcopy %armv8%\lib%libName%.so %tgAndroid%\arm64-v8a /y
        IF %errorlevel% neq 0 (
        echo copy android v8a so fail
        pause
        GOTO END
    )


goto:eof



:END