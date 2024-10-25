CHCP 65001


rem custom [0:ARATEK | 1:MIAXIS | 2:win7 | 3:fangzheng | new]
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
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %winDir% /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %winDir% /y

    rem copy win_x86
    rem xcopy %vs86Dir%%libName%.dll %targetDir%\libx86 /y
    xcopy %vs86Dir%%libName%.lib %winDir%\libx86	/y
    xcopy %vs86Dir%%libName%.dll %winDir%\Release	/y

    rem copy win_x64
    rem xcopy %vs64Dir%%libName%.dll %targetDir%\libx64 /y
    xcopy %vs64Dir%%libName%.lib %winDir%\libx64 /y
    xcopy %vs64Dir%%libName%.dll %winDir%\x64\Release /y

goto:eof



:copyAndroid
    echo "copy android"
    set androidv7Dir=%SDKDir%cmake-build-release-armeabi-v7a\libFAP\
    set androidv8Dir=%SDKDir%cmake-build-release-arm64-v8a\libFAP\

    xcopy %androidv7Dir%lib%libName%.so %androidDir%armeabi-v7a /y
    xcopy %androidv8Dir%lib%libName%.so %androidDir%arm64-v8a /y

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %androidDir%include /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %androidDir%include /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %androidDir%include /y
goto:eof




:END
