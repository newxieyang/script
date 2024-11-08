CHCP 65001


set custom[0]=ARATEK
set custom[1]=MIAXIS
set custom[2]=win7
set custom[3]=fangzheng
set custom[4]=new
set custom[5]=kejin
set custom[6]=yinken
set custom[7]=huantian

@echo off


set "max=7"
for /l %%i in (1,1,%max%) do (
    echo !custom[%%i]!
)

 GOTO END

if "%1" == "" (
	echo "0 build ARTEK"
	echo "1 build MIAXIS"
	echo "2 build win7"
	echo "3 build fangzheng"
	echo "4 build new"
    echo "5 build kejin"
	echo "6 build yinken"
	echo "7 build huantian"
	pause
    GOTO END
)

rem custom [0:ARATEK | 1:MIAXIS | 2:win7 | 3:fangzheng | 4:new | 5:kejin | 6:yinken | 7:huantian]
set custom=1
set customStr=win7
set libName=FAP60
set customIndex=%1
set platformIndex=%2

if %customIndex% EQU 0 (
	set customStr=ARATEK
    set libName=AraDevice
)
if %customIndex% EQU 1 (
	set customStr=MIAXIS
)

if %customIndex% EQU 2 (
	set customStr=win7
)

if %customIndex% EQU 3 (
	set customStr=fangzheng
)

if %customIndex% EQU 4 (
	set customStr=new
)

if %customIndex% EQU 5 (
	set customStr=kejin
)

if %customIndex% EQU 6 (
	set customStr=yinken
)

if %customIndex% EQU 7 (
	set customStr=huantian
)


echo "genareate G6SDK"
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
    xcopy %vs86Dir%%libName%.lib %winDir%\libx86	/y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )
    xcopy %vs86Dir%%libName%.dll %winDir%\Release	/y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )

    rem copy win_x64
    rem xcopy %vs64Dir%%libName%.dll %targetDir%\libx64 /y
    xcopy %vs64Dir%%libName%.lib %winDir%\libx64 /y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )
    xcopy %vs64Dir%%libName%.dll %winDir%\x64\Release /y
        IF %errorlevel% neq 0 (
        echo copy win OXiScanUltimateApi_err.h file fail
        pause
        GOTO END
    )

goto:eof



:copyAndroid
    echo "copy android"
    
    @REM set androidv7Dir=%SDKDir%cmake-build-release-armeabi-v7a\libFAP\
    @REM set androidv8Dir=%SDKDir%cmake-build-release-arm64-v8a\libFAP\
    @REM if %customIndex% EQU 0 (
	@REM     %androidv7Dir%=%SDKDir%cmake-build-release-arm7-r18\libFAP\
    @REM     %androidv8Dir%=%SDKDir%cmake-build-release-arm8-r18\libFAP\
    @REM )

    echo %androidDir%
    echo %SDKDir%

    set androidv7Dir=%SDKDir%cmake-build-release-arm7-r18\libFAP\
    set androidv8Dir=%SDKDir%cmake-build-release-arm8-r18\libFAP\
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
