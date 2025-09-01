
setlocal enabledelayedexpansion 
set custom[0]=oxi
set custom[1]=DERMALOG
set custom[2]=fangzheng

if "%1" == "" (
    for /l %%n in (0,1,9) do ( 
    echo %%n build !custom[%%n]! 
    )
	pause
    GOTO END
)

set customIndex=%1
set platformIndex=%2
set customStr=!custom[%customIndex%]!


set SDKDir=D:\git\oxi\g7\FAP70\


set versionFile=%SDKDir%\libFAP\include\version.h
for /f "tokens=3 delims= " %%i in ('findstr /C:"#define OXISCAN_VERSION_MAJOR " %versionFile%') do set MAJOR=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:" OXISCAN_VERSION_MINOR " %versionFile%') do set MINOR=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:" OXISCAN_VERSION_PATCH " %versionFile%') do set PATCH=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:" OXISCAN_VERSION_BUILD " %versionFile%') do set BUILD=%%i 
set "MAJOR=%MAJOR: =%"
set "MINOR=%MINOR: =%"
set "PATCH=%PATCH: =%"
set "BUILD=%BUILD: =%"

set version=%MAJOR%.%MINOR%.%PATCH%.%BUILD%

set mkVer=%SDKDir%\OXiMKImgLib\src\oxi_mk_image_process.cpp
for /f "tokens=3 delims= " %%i in ('findstr /C:"version[0] = " %mkVer%') do set MAJOR=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:"version[1] = " %mkVer%') do set MINOR=%%i 
for /f "tokens=3 delims= " %%i in ('findstr /C:"version[2] = " %mkVer%') do set PATCH=%%i 
set "MAJOR=%MAJOR: =%"
set "MINOR=%MINOR: =%"
set "PATCH=%PATCH: =%"

set mkVerStr=%MAJOR%.%MINOR%.%PATCH%
set mkVerStr=%mkVerStr:;=%
echo %mkVerStr%

@REM set targetDir=D:\G7SDKLib\G7SDKv%version%
@REM set zipFilePathName=D:\G7SDKLib\G7SDKv%version%.zip
set vs64Dir=%SDKDir%cmake-build-release-vs2019_x64\libFAP\Release\
set vs86Dir=%SDKDir%cmake-build-release-vs2019_x86\libFAP\Release\
set winDir=D:\git\oxi\g7\g7010WinDemo\

md %targetDir%

set targetDir=D:\G7SDKLib\%customStr%
if exist %targetDir% (
   echo "文件存在"
) else (
::创建文件夹
    md %targetDir% 
)
set targetDir=D:\G7SDKLib\%customStr%\G7SDKv%version%mk%mkVerStr%
set zipFilePathName=%targetDir%.zip

md %targetDir%

@REM echo copy include
md %targetDir%\include
xcopy %SDKDir%libFAP\include\OXiScanAPI.h %targetDir%\include /y
xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %targetDir%\include /y
xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %targetDir%\include /y
@REM if %custom% EQU 1 (
@REM 	echo "1"
@REM )



@REM rem copy AI model
@REM md %targetDir%\AI_model
@REM xcopy %androidDir%libFAP\src\main\assets\*.onnx %targetDir%\AI_model
@REM xcopy D:\G6SDKLib\*.bmp %targetDir%\AI_model


set winDemoDir=%targetDir%\G7_win_demo_sourceCode

rem copy win demo source code
md %winDemoDir%
md %winDemoDir%\libx64
md %winDemoDir%\libx86
md %winDemoDir%\res
xcopy %winDir%*.cpp %winDemoDir% /y
xcopy %winDir%*.h %winDemoDir%  /y
xcopy %winDir%*.rc %winDemoDir%  /y
xcopy %winDir%G7WinDemo.* %winDemoDir%  /y
xcopy %winDir%res\*.* %winDemoDir%\res  /y
xcopy %winDir%libx64\*.* %winDemoDir%\libx64  /y
xcopy %winDir%libx86\*.* %winDemoDir%\libx86  /y

md %targetDir%\winx86DemoWithLib
rem copy win_x86
xcopy %vs86Dir%*.dll %targetDir%\winx86DemoWithLib /y
xcopy %vs86Dir%FAP70.lib %targetDir%\winx86DemoWithLib /y
@REM xcopy %SDKDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x86\onnxruntime.dll %targetDir%\winx86DemoWithLib
xcopy %winDir%\Release\*.exe %targetDir%\winx86DemoWithLib /y
@REM xcopy %androidDir%libFAP\src\main\assets\*.onnx %winDemoDir%\samplex86    /y

rem copy win_x64
md %targetDir%\winx64DemoWithLib
xcopy %vs64Dir%*.dll %targetDir%\winx64DemoWithLib /y
xcopy %vs64Dir%FAP70.lib %targetDir%\winx64DemoWithLib /y
@REM xcopy %SDKDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x64\onnxruntime.dll %targetDir%\winx64DemoWithLib
xcopy %winDir%\x64\Release\*.exe %targetDir%\winx64DemoWithLib /y
@REM xcopy %androidDir%libFAP\src\main\assets\*.onnx %winDemoDir%\samplex64    /y
@REM xcopy %winDir%g6010_sdk_debug\*.onnx winDemoDir\sample   /y

@REM rem copy android source code
@REM md %targetDir%\Android
@REM md %targetDir%\Android\G6010ASSample
@REM xcopy %androidDir% %targetDir%\Android\G6010ASSample /exclude:exclude.txt /s /y /v
@REM rd /s /q %targetDir%\Android\G6010ASSample\.gradle
@REM rd /s /q %targetDir%\Android\G6010ASSample\gradle


@REM del /f /s /q %targetDir%\Android\G6010ASSample\libFAP\src\main\assets\*.onnx	
@REM del /f /s /q %winDemoDir%\g6010_sdk_debug\*.onnx


@REM xcopy %androidDir%app\build\outputs\apk\debug\*.apk %targetDir%\Android  /y

@REM rem copy document
md %targetDir%\doc
xcopy D:\G7SDKLib\doc\*.* %targetDir%\doc /y


@REM md %linuxDir%
@REM @REM md %linuxDir%\aarch
@REM @REM md %linuxDir%\x64
@REM xcopy D:\G6SDKLib\linux\testG6SDK%version%.zip %linuxDir% /y

7z a -tzip %zipFilePathName% %targetDir% 
@pause