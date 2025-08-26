

@echo off

echo "1 GerSDK build"
echo "2 GerSDK copy"
echo "3 GerSDK generate document"
echo "4 GerSDK archive"

REM 检查 Conda 是否激活
if defined CONDA_PREFIX (
    echo Conda activate: %CONDA_PREFIX%
    echo Current Conda env: %CONDA_DEFAULT_ENV%
) else (
    echo Conda is not activate
    conda activate base
)

set "script_dir=%~dp0"
@REM echo "%script_dir%"
cd %script_dir%

set /p input=please input number you choose:


if "%input%"=="1" (
    echo "GerSDK build Win/Android SDK"
    call g7buildAndroid.bat
	GOTO END
)

if "%input%"=="2" (
    echo "copy GerSDK to Gser Win/Android simple code"
    python %script_dir%gserSDK.py
	GOTO END
)

if "%input%"=="3" (
    echo "GerSDK generate document start"
    python %script_dir%genSDKAPI.py
    echo "GerSDK generate document end"
	GOTO END
)

if "%input%"=="4" (
    echo "will create GSer SDK archive start"
    python %script_dir%gserCreateVersion.py
    echo "will create GSer SDK archive end"
	GOTO END
)

:END