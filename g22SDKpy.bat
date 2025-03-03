CHCP 65001
@echo off

set libName=FAP2020

set sourceDir=D:\git\oxi\g2\g2020\
set SDKDir=%sourceDir%G2020SDK\
set androidDir=%sourceDir%G2020Android\
set winDir=%sourceDir%G2020WinDemo\
set linuxDir=%targetDir%\Linux



if "%1"=="" (
    call :copyWin
    call :copyAndroid
	GOTO END

)

if %1 EQU 1 (
    call :copyWin 
	GOTO END
)

if %1 EQU 2 (
    call :copyAndroid 
	GOTO END
)


:copyWin


    echo "copy win"
    set vs64Dir=%SDKDir%cmake-build-release-vs2019_x64\libFAP\Release\
    set vs86Dir=%SDKDir%cmake-build-release-vs2019_x86\libFAP\Release\

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %winDir% /y
      IF %errorlevel% neq 0 (
        echo copy win OXiScanAPI.h file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %winDir% /y
      IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimate.h file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %winDir% /y
      IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )

    rem copy win_x86
    rem xcopy %vs86Dir%%libName%.dll %targetDir%\libx86 /y
    xcopy %vs86Dir%%libName%.lib %winDir%libx86	/y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )
    xcopy %vs86Dir%%libName%.dll %winDir%Release	/y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )

    rem copy win_x64
    rem xcopy %vs64Dir%%libName%.dll %targetDir%\libx64 /y
    xcopy %vs64Dir%%libName%.lib %winDir%libx64 /y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )
    xcopy %vs64Dir%%libName%.dll %winDir%x64\Release /y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )

goto:eof



:copyAndroid
    echo "copy android"
    
    set androidv7Dir=%SDKDir%cmake-build-release-armeabi-v7a\libFAP\
    set androidv8Dir=%SDKDir%cmake-build-release-arm64-v8a\libFAP\


    echo %androidDir%
    echo %SDKDir%

    @REM if %customIndex% EQU 0 (
    @REM     set androidv7Dir=%SDKDir%cmake-build-release-arm7-r18\libFAP\
    @REM     set androidv8Dir=%SDKDir%cmake-build-release-arm8-r18\libFAP\
    @REM )


    set jniDir=%androidDir%libFAP\src\main\cpp\

    xcopy %androidv7Dir%lib%libName%.so %jniDir%armeabi-v7a /y
    IF %errorlevel% neq 0 (
        echo copy android v7a so  fail
        pause
        GOTO END
    )
    xcopy %androidv8Dir%lib%libName%.so %jniDir%arm64-v8a /y
        IF %errorlevel% neq 0 (
        echo copy android v8a so fail
        pause
        GOTO END
    )

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %jniDir%include /y
    IF %errorlevel% neq 0 (
         echo copy android OXiScanAPI.h file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %jniDir%include /y
    IF %errorlevel% neq 0 (
        echo copy android OXiScanUltimate.h file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %jniDir%include /y
    IF %errorlevel% neq 0 (
        echo copy android OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )

goto:eof




:END
