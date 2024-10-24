@echo off
CHCP 65001
set version=1.0.49

set projectDir=D:\git\oxi\g6\FAP6010
set targetDir=D:\G6SDKLib
set winDir=D:\git\oxi\g6\g6010WinDemo
set androidDir=D:\git\oxi\g6\G6010Android\
set winTarget=%targetDir%\win%version%
set winX86Target=%winTarget%\win-x86
set winX64Target=%winTarget%\win-x64
set winDemoSourceCode=%winTarget%\winDemoSourceCode
set androidTarget=%targetDir%\android%version%
set androidSource=%androidTarget%\G6010Android

if "%1" == "" (
	echo "1 build win x86 x64 demo"
	echo "2 build win x86 x64 demo with source code"
	echo "3 build android demo"
	echo "4 build android demo with source code"
	pause
    GOTO END
)

if %1 EQU 1 (
	call :copyWinDemo 
	GOTO END
)
if %1 EQU 2 (
	call :copyWinDemo 
	call :copyWinSourceCode
	GOTO END
)

if %1 EQU 3 (
	call :copyAndoirdSourceCode 
	GOTO END
)

:copyWinDemo
	echo "copy win demo start"

	IF NOT EXIST %winTarget% (
    	md %winTarget%
	) 

	IF NOT EXIST %winX86Target% (
    	md %winX86Target%
	) 

	rem copy win_x86
	xcopy %winDir%\Release\*.dll %winX86Target% /y
	xcopy %winDir%\Release\*.exe %winX86Target% /y

	IF NOT EXIST %winX64Target% (
    	md %winX64Target%
	) 
	xcopy %winDir%\x64\Release\*.dll %winX64Target% /y
	xcopy %winDir%\x64\Release\*.exe %winX64Target% /y

	echo "copy win demo end"
goto:eof

:copyWinSourceCode
	echo "copy win demo source code start"

	IF NOT EXIST %winTarget% (
    	md %winTarget%
	) 

	IF NOT EXIST %winDemoSourceCode% (
    	md %winDemoSourceCode%
	) 

	md %winDemoSourceCode%\libx64
	md %winDemoSourceCode%\libx86
	md %winDemoSourceCode%\res
	xcopy %winDir%*.cpp %winDemoSourceCode% /y
	xcopy %winDir%*.h %winDemoSourceCode%  /y
	xcopy %winDir%*.rc %winDemoSourceCode%  /y
	xcopy %winDir%g6010WinDemo.* %winDemoSourceCode%  /y
	xcopy %winDir%res\*.* %winDemoSourceCode%\res  /y
	xcopy %winDir%libx64\*.* %winDemoSourceCode%\libx64  /y
	xcopy %winDir%libx86\*.* %winDemoSourceCode%\libx86  /y

	echo "copy win demo source code end"

goto:eof


:copyAndoirdSourceCode

	echo "copy Android demo source code start"

	IF NOT EXIST %androidTarget% (
    	md %androidTarget%
	) 

	IF NOT EXIST %androidSource% (
    	md %androidSource%
	) 
	xcopy %androidDir% %androidSource% /exclude:exclude.txt /s /y /v
	rd /s /q %targetDir%\Android\G6010Android\.gradle
	rd /s /q %targetDir%\Android\G6010Android\gradle

	del /f /s /q %targetDir%\Android\G6010Android\libFAP\src\main\assets\*.onnx	
	del /f /s /q %targetDir%\G6_win_demo_sourceCode\g6010_sdk_debug\*.onnx
	
	echo "copy Android demo source code end"
goto:eof



:END