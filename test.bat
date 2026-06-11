@echo off
setlocal enabledelayedexpansion

set "versionFile=D:\git\oxi\g6\FAP6010_new\version.cmake"

set "MAJOR=0"
set "MINOR=0"
set "PATCH=0"
set "BUILD=0"

if not exist "%versionFile%" (
    echo [ERROR] Cannot find: %versionFile%
    pause
    exit /b
)

:: 使用 /C: 确保精确匹配变量名，避开最后一行合成的字符串
for /f "tokens=2" %%a in ('findstr /C:"FAP_VERSION_MAJOR " "%versionFile%"') do (
    set "val=%%a"
    set "MAJOR=!val:)=!"
)
for /f "tokens=2" %%a in ('findstr /C:"FAP_VERSION_MINOR " "%versionFile%"') do (
    set "val=%%a"
    set "MINOR=!val:)=!"
)
for /f "tokens=2" %%a in ('findstr /C:"FAP_VERSION_PATCH " "%versionFile%"') do (
    set "val=%%a"
    set "PATCH=!val:)=!"
)
for /f "tokens=2" %%a in ('findstr /C:"FAP_VERSION_BUILD " "%versionFile%"') do (
    set "val=%%a"
    set "BUILD=!val:)=!"
)

:: 去掉可能存在的双引号
set "MAJOR=!MAJOR:"=!"
set "MINOR=!MINOR:"=!"
set "PATCH=!PATCH:"=!"
set "BUILD=!BUILD:"=!"

:: 最终拼接
set "version=!MAJOR!.!MINOR!.!PATCH!.!BUILD!"

echo ==========================
echo 目标文件: %versionFile%
echo 最终版本: %version%
echo ==========================

pause