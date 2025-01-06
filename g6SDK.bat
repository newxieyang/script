CHCP 65001
@echo off

setlocal enabledelayedexpansion 
set custom[0]=ARATEK
set custom[1]=MIAXIS
set custom[2]=win7
set custom[3]=fangzheng
set custom[4]=new
set custom[5]=kejin
set custom[6]=yinken
set custom[7]=huantian
set custom[8]=Thales




if "%1" == "" (
    for /l %%n in (0,1,8) do ( 
    echo %%n build !custom[%%n]! 
    )
	pause
    GOTO END
)

rem custom [0:ARATEK | 1:MIAXIS | 2:win7 | 3:fangzheng | 4:new | 5:kejin | 6:yinken | 7:huantian | 8:Thales]
@REM set custom=1
set libName=FAP60
set customIndex=%1
set platformIndex=%2
set customStr=!custom[%customIndex%]!



if %customIndex% EQU 0 (
	@REM set customStr=ARATEK
    set libName=AraDevice
)



echo "genareate custom  %customStr% G6SDK libName %libName%"
echo off

set sourceDir=D:\git\oxi\g6\
set SDKDir=%sourceDir%FAP6010_%customStr%\
set androidDir=%sourceDir%G6010Android_%customStr%\
set winDir=%sourceDir%g6010WinDemo_%customStr%\
set linuxDir=%targetDir%\Linux




@REM set targetDir=D:\G6SDKLib\G6SDKtestv%version%
@REM set zipFilePathName=D:\G6SDKLib\G6SDKtestv%version%.zip





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





:copyWin

    if %customIndex% EQU 4 (
        set winDir=%sourceDir%g6MFC_%customStr%\
    )

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
    if %customIndex% EQU 0 (
	    SET androidv7Dir=%SDKDir%cmake-build-release-arm7-r18\libFAP\
        SET androidv8Dir=%SDKDir%cmake-build-release-arm8-r18\libFAP\
    )

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
