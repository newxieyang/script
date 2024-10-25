set version=1.0.6
rem custom 1 ARATEK 2 CASTL 3 MIAXIS 
set custom=1 
set targetDir=D:\G7SDKLib\G7SDKv%version%
set zipFilePathName=D:\G7SDKLib\G7SDKv%version%.zip

set jniDir=D:\git\oxi\g7\FAP70\
set vs64Dir=%jniDir%cmake-build-release-vs2019_x64\libFAP\Release\
set vs86Dir=%jniDir%cmake-build-release-vs2019_x86\libFAP\Release\
set winDir=D:\git\oxi\g7\g7010WinDemo\

@REM set androidDir=D:\git\oxi\g6\G6010ASSample\
@REM set linuxDir=%targetDir%\Linux

md %targetDir%

@REM echo copy include
md %targetDir%\include
xcopy %jniDir%libFAP\include\OXiScanAPI.h %targetDir%\include /y
xcopy %jniDir%libFAP\include\OXiScanUltimate.h %targetDir%\include /y
xcopy %jniDir%libFAP\include\OXiScanUltimateApi_err.h %targetDir%\include /y
if %custom% EQU 1 (
	echo "1"
)



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
xcopy %vs86Dir%FAP70.dll %targetDir%\winx86DemoWithLib /y
xcopy %vs86Dir%FAP70.lib %targetDir%\winx86DemoWithLib /y
@REM xcopy %jniDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x86\onnxruntime.dll %targetDir%\winx86DemoWithLib
xcopy %winDir%\Release\*.exe %targetDir%\winx86DemoWithLib /y
@REM xcopy %androidDir%libFAP\src\main\assets\*.onnx %winDemoDir%\samplex86    /y

rem copy win_x64
md %targetDir%\winx64DemoWithLib
xcopy %vs64Dir%FAP70.dll %targetDir%\winx64DemoWithLib /y
xcopy %vs64Dir%FAP70.lib %targetDir%\winx64DemoWithLib /y
@REM xcopy %jniDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x64\onnxruntime.dll %targetDir%\winx64DemoWithLib
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
xcopy D:\G7SDKLib\*.docx %targetDir% /y
xcopy D:\G7SDKLib\*.png %targetDir% /y
xcopy D:\G7SDKLib\*.txt %targetDir% /y


@REM md %linuxDir%
@REM @REM md %linuxDir%\aarch
@REM @REM md %linuxDir%\x64
@REM xcopy D:\G6SDKLib\linux\testG6SDK%version%.zip %linuxDir% /y

@REM 7z a -tzip %zipFilePathName% %targetDir% 
@pause