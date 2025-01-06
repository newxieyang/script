CHCP 65001
@echo off

setlocal enabledelayedexpansion 
set custom[0]=ARATEK
set custom[1]=ARATEK_new
set custom[2]=ARATEK_bak
set custom[3]=ARATEK_test





if "%1" == "" (
    for /l %%n in (0,1,8) do ( 
    echo %%n build !custom[%%n]! 
    )
	pause
    GOTO END
)

rem custom [0:ARATEK | 1:MIAXIS | 2:win7 | 3:fangzheng | 4:new | 5:kejin | 6:yinken | 7:huantian | 8:Thales]
@REM set custom=1
set libName=AraDevice
set customIndex=%1
set platformIndex=%2
set customStr=!custom[%customIndex%]!



if %customIndex% EQU 0 (
	@REM set customStr=ARATEK
    set libName=AraDevice
)



echo "genareate custom  %customStr% G6SDK libName %libName%"


set sourceDir=D:\git\oxi\g6\
set SDKDir=%sourceDir%FAP6010_%customStr%\
set androidDir=%sourceDir%G6010Android_ARATEK\



call :copyAndroid
GOTO END



:copyAndroid
    echo "copy android"
    echo "copy android %platformIndex%"
    
    set androidv7Dir=%SDKDir%cmake-build-release-armeabi-v7a\libFAP\
    set androidv8Dir=%SDKDir%cmake-build-release-arm64-v8a\libFAP\
    if "%platformIndex%" == "" (
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
