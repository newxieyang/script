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


    set vs64Dir=%SDKDir%cmake-build-release-vs2019_x64\libFAP\Release\
    set vs86Dir=%SDKDir%cmake-build-release-vs2019_x86\libFAP\Release\

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %targetDir% /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %targetDir% /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %targetDir% /y

    rem copy win_x86
    rem xcopy %vs86Dir%FAP60.dll %targetDir%\libx86 /y
    xcopy %vs86Dir%FAP70.lib %targetDir%\libx86	/y
    xcopy %vs86Dir%FAP70.dll %targetDir%\Release	/y

    rem copy win_x64
    rem xcopy %vs64Dir%FAP60.dll %targetDir%\libx64 /y
    xcopy %vs64Dir%FAP70.lib %targetDir%\libx64 /y
    xcopy %vs64Dir%FAP70.dll %targetDir%\x64\Release /y

goto:eof



:copyAndroid
rem copy android source code

md %targetDir%\Android
xcopy %androidDir%app\build\outputs\apk\debug\*.apk %targetDir%\Android  /y
goto:eof



:copyLinux
@REM md %linuxDir%
@REM @REM md %linuxDir%\aarch
@REM @REM md %linuxDir%\x64
@REM xcopy D:\G6SDKLib\linux\testG6SDK%version%.zip %linuxDir% /y
goto:eof




:END
7z a -tzip %zipFilePathName% %targetDir% 