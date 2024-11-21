CHCP 65001



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


echo "genareate G6SDK"
echo off

set sourceDir=D:\git\oxi\g6\
set SDKDir=%sourceDir%FAP6010_%customStr%\
set androidDir=%sourceDir%G6010Android_%customStr%\
set winDir=%sourceDir%g6010WinDemo_%customStr%\
set linuxDir=%targetDir%\Linux
set versionFile=%SDKDir%\libFAP\include\Version.h


for /f "tokens=3 delims= " %%i in ('findstr /C:"#define OXISCAN_VERSION_MAJOR " %versionFile%') do set MAJOR=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:" OXISCAN_VERSION_MINOR " %versionFile%') do set MINOR=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:" OXISCAN_VERSION_PATCH " %versionFile%') do set PATCH=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:" OXISCAN_VERSION_BUILD " %versionFile%') do set BUILD=%%i 
set "MAJOR=%MAJOR: =%"
set "MINOR=%MINOR: =%"
set "PATCH=%PATCH: =%"
set "BUILD=%BUILD: =%"


set version=%MAJOR%.%MINOR%.%PATCH%.%BUILD%


set targetDir=D:\G6SDKLib\%customStr%
if exist %targetDir% (
   echo "文件存在"
) else (
::创建文件夹
    md %targetDir% 
)

set targetDir=D:\G6SDKLib\%customStr%\G6SDKtestv%version%
set zipFilePathName=%targetDir%.zip



rd /s /q %targetDir%
rd /s /q %targetDir%.zip



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


:copyAIModel
rem copy AI model
md %targetDir%\AI_model
@REM xcopy %androidDir%libFAP\src\main\assets\*.onnx %targetDir%\AI_model
@REM xcopy D:\G6SDKLib\*.bmp %targetDir%\AI_model
goto:eof


:copyWin


md %targetDir%\winx86DemoWithLib
rem copy win_x86
xcopy %winDir%\Release\*.exe %targetDir%\winx86DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy winx86 exe file fail
    pause
    GOTO END
)
xcopy %winDir%\Release\*.dll %targetDir%\winx86DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy winx86 dll file fail
    pause
    GOTO END
)


rem copy win_x64
md %targetDir%\winx64DemoWithLib
xcopy %winDir%\x64\Release\*.exe %targetDir%\winx64DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy winx64 exe file fail
    pause
    GOTO END
)
xcopy %winDir%\x64\Release\*.dll %targetDir%\winx64DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy winx64 dll file fail
    pause
    GOTO END
)

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