echo "copy G7SDK to project"
echo OFF

setlocal enabledelayedexpansion 
set custom[0]=oxi
set custom[1]=fangzheng


if "%1" == "" (
    for /l %%n in (0,1,9) do ( 
    echo %%n build !custom[%%n]! 
    )
	pause
    GOTO END
)


set customIndex=%1
set customStr=!custom[%customIndex%]!


set SDKDir=D:\git\oxi\g7\FAP70\
set targetDir=D:\git\oxi\g7\g7010WinDemo_%customStr%


if "%2"=="" (
    call :copyWin
    call :copyAndroid
	GOTO END
)

if %2 EQU 1 (
    call :copyWin 
	GOTO END
)

if %2 EQU 2 (
    call :copyAndroid 
	GOTO END
)
echo %time%


:copyWin
    echo "copy win"
    set vs64Dir=%SDKDir%cmake-build-release-vs2019_x64\libFAP\Release\
    set vs86Dir=%SDKDir%cmake-build-release-vs2019_x86\libFAP\Release\

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %targetDir% /y
    IF %errorlevel% neq 0 (
        echo copy include OXiScanAPI.h file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %targetDir% /y
    IF %errorlevel% neq 0 (
        echo copy include OXiScanUltimate.h file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %targetDir% /y
    IF %errorlevel% neq 0 (
        echo copy include OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )

    rem copy win_x86
    rem xcopy %vs86Dir%FAP60.dll %targetDir%\libx86 /y
    xcopy %vs86Dir%FAP70.lib %targetDir%\libx86	/y
    IF %errorlevel% neq 0 (
        echo copy winx86 lib file fail
        pause
        GOTO END
    )
    xcopy %vs86Dir%FAP70.dll %targetDir%\Release	/y
    IF %errorlevel% neq 0 (
        echo copy winx86 dll file fail
        pause
        GOTO END
    )

    rem copy win_x64
    rem xcopy %vs64Dir%FAP60.dll %targetDir%\libx64 /y
    xcopy %vs64Dir%FAP70.lib %targetDir%\libx64 /y
    IF %errorlevel% neq 0 (
        echo copy x64 lib file fail
        pause
        GOTO END
    )
    xcopy %vs64Dir%FAP70.dll %targetDir%\x64\Release /y
    IF %errorlevel% neq 0 (
        echo copy x64 dll file fail
        pause
        GOTO END
    )
    GOTO END
goto:eof


:copyAndroid
    echo "copy android"
    set androidDir=D:\git\oxi\g7\G7010Android\libFAP\src\main\cpp\
    set androidv7Dir=%SDKDir%cmake-build-release-armeabi-v7a\libFAP\
    set androidv8Dir=%SDKDir%cmake-build-release-arm64-v8a\libFAP\
    echo %androidv7Dir%

    xcopy %androidv7Dir%libFAP70.so %androidDir%armeabi-v7a /y
    IF %errorlevel% neq 0 (
        echo copy v7a libFAP70 so fail
        pause
        GOTO END
    )
    xcopy %androidv8Dir%libFAP70.so %androidDir%arm64-v8a /y
    IF %errorlevel% neq 0 (
        echo copy v8a libFAP70 so fail
        pause
        GOTO END
    )

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %androidDir%include /y
    IF %errorlevel% neq 0 (
        echo copy android OXiScanAPI.h file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %androidDir%include /y
    IF %errorlevel% neq 0 (
        echo copy android OXiScanUltimate.h  file fail
        pause
        GOTO END
    )
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %androidDir%include /y
    IF %errorlevel% neq 0 (
        echo copy android OXiScanUltimateApi_err.h  file fail
        pause
        GOTO END
    )
goto:eof

:END