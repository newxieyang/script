
setlocal enabledelayedexpansion 




set SDKDir=D:\git\oxi\g2\g2020\G2020SDK\
set androidDir=D:\git\oxi\g2\g2020\G2020Android\


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



@REM set targetDir=D:\G2SDKLib\G7SDKv%version%
@REM set zipFilePathName=D:\G2SDKLib\G7SDKv%version%.zip
set vs64Dir=%SDKDir%cmake-build-release-vs2019_x64\libFAP\Release\
set vs86Dir=%SDKDir%cmake-build-release-vs2019_x86\libFAP\Release\
set winDir=D:\git\oxi\g2\g2020\G2020WinDemo\

md %targetDir%

set targetDir=D:\G2SDKLib\
if exist %targetDir% (
   echo "文件存在"
) else (
::创建文件夹
    md %targetDir% 
)
set targetDir=D:\G2SDKLib\G2SDKv%version%
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


set winDemoDir=%targetDir%\G2_win_demo_sourceCode

rem copy win demo source code
md %winDemoDir%
md %winDemoDir%\libx64
md %winDemoDir%\libx86
md %winDemoDir%\res
xcopy %winDir%*.cpp %winDemoDir% /y
xcopy %winDir%*.h %winDemoDir%  /y
xcopy %winDir%*.rc %winDemoDir%  /y
xcopy %winDir%OXiDemo.* %winDemoDir%  /y
xcopy %winDir%res\*.* %winDemoDir%\res  /y
xcopy %winDir%libx64\*.* %winDemoDir%\libx64  /y
xcopy %winDir%libx86\*.* %winDemoDir%\libx86  /y


md %targetDir%\winx86DemoWithLib
rem copy win_x86
@REM xcopy %vs86Dir%%libName%.dll %targetDir%\winx86DemoWithLib /y
@REM xcopy %vs86Dir%%libName%.lib %targetDir%\winx86DemoWithLib /y
@REM xcopy %SDKDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x86\onnxruntime.dll %targetDir%\winx86DemoWithLib
xcopy %winDir%\Release\*.exe %targetDir%\winx86DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy WinX86 demo .exe fail
    pause
    GOTO END
)
xcopy %winDir%\Release\*.dll %targetDir%\winx86DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy WinX86 demo .dll fail
    pause
    GOTO END
)
@REM xcopy %androidDir%libFAP\src\main\assets\*.onnx %winDemoDir%\samplex86    /y

rem copy win_x64
md %targetDir%\winx64DemoWithLib
@REM xcopy %vs64Dir%%libName%.dll %targetDir%\winx64DemoWithLib /y
@REM xcopy %vs64Dir%%libName%.lib %targetDir%\winx64DemoWithLib /y
@REM xcopy %SDKDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x64\onnxruntime.dll %targetDir%\winx64DemoWithLib
xcopy %winDir%\x64\Release\*.exe %targetDir%\winx64DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy WinX64 demo .exe fail
    pause
    GOTO END
)
xcopy %winDir%\x64\Release\*.dll %targetDir%\winx64DemoWithLib /y
IF %errorlevel% neq 0 (
    echo copy WinX64 demo .dll fail
    pause
    GOTO END
)



@REM rem copy android source code
md %targetDir%\Android
md %targetDir%\Android\G2020Android
xcopy %androidDir% %targetDir%\Android\G2020Android /EXCLUDE:D:\git\script\exclude  /y /v /s



@REM del /f /s /q %targetDir%\Android\G6010ASSample\libFAP\src\main\assets\*.onnx	
@REM del /f /s /q %winDemoDir%\g6010_sdk_debug\*.onnx


xcopy %androidDir%app\build\outputs\apk\debug\*.apk %targetDir%\Android  /y


@REM del /f /s /q %targetDir%\Android\G6010ASSample\libFAP\src\main\assets\*.onnx	
@REM del /f /s /q %winDemoDir%\g6010_sdk_debug\*.onnx


@REM xcopy %androidDir%app\build\outputs\apk\debug\*.apk %targetDir%\Android  /y

@REM rem copy document
md %targetDir%\doc
xcopy D:\G2SDKLib\doc\*.* %targetDir%\doc /y


@REM md %linuxDir%
@REM @REM md %linuxDir%\aarch
@REM @REM md %linuxDir%\x64
@REM xcopy D:\G6SDKLib\linux\testG6SDK%version%.zip %linuxDir% /y

7z a -tzip %zipFilePathName% %targetDir% 
@pause