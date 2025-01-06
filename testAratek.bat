set sourceDir=D:\git\oxi\g6\
set SDKDir=%sourceDir%FAP6010_ARATEK_test2\
set androidDir=%sourceDir%G6010Android_ARATEK\
set jniDir=%androidDir%libFAP\src\main\cpp\

@echo off

set custom[0]=libUtils
set custom[1]=libAI
set custom[2]=mk
set custom[3]=libFAP

set libName[0]=libOXiUtils
set libName[1]=libALGO
set libName[2]=mk
set libName[3]=libAraDevice


set customIndex=%1
set platformIndex=%2


set customStr=!custom[%customIndex%]!
set libNameStr=!libName[%customIndex%]!

if "%1" == "" (
    for /l %%n in (0,1,8) do ( 
    echo %%n build !custom[%%n]! 
    )
	pause
    GOTO END
)


:copyUtils

    set androidv7Dir=%SDKDir%cmake-build-release-armeabi-v7a\%customStr%\
    set androidv8Dir=%SDKDir%cmake-build-release-arm64-v8a\%customStr%\
    if "%platformIndex%" == "" (
	    SET androidv7Dir=%SDKDir%cmake-build-release-arm7-r18\%customStr%\
        SET androidv8Dir=%SDKDir%cmake-build-release-arm8-r18\%customStr%\
    )

    @REM xcopy %androidv7Dir%%libNameStr%.so %SDKDir%%customStr%\lib\android\armeabi-v7a /y
    @REM IF %errorlevel% neq 0 (
    @REM     echo copy android v7a %libNameStr%.so  fail
    @REM     pause
    @REM     GOTO END
    @REM )
    @REM xcopy %androidv8Dir%%libNameStr%.so %SDKDir%%customStr%\lib\android\arm64-v8a /y
    @REM     IF %errorlevel% neq 0 (
    @REM     echo copy android v8a %libNameStr%.so fail
    @REM     pause
    @REM     GOTO END
    @REM )

    xcopy %androidv7Dir%%libNameStr%.so %jniDir%armeabi-v7a /y
    IF %errorlevel% neq 0 (
        echo copy android v7a %libNameStr%.so fail
        pause
        GOTO END
    )
    xcopy %androidv8Dir%%libNameStr%.so %jniDir%arm64-v8a /y
        IF %errorlevel% neq 0 (
        echo copy android v8a %libNameStr%.so fail
        pause
        GOTO END
    )

goto:eof