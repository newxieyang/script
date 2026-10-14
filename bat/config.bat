@echo OFF
REM ============================================================
REM 公共路径配置（cmd 侧读取器）
REM
REM 真源仍是仓库根 paths.json —— 本文件不存路径，只是把
REM ..\ps\env_paths.ps1 -Batch 的输出（set "name=value" 行）执行一遍。
REM 因此 Windows 侧的路径/派生逻辑只有 ps\env_paths.ps1 一份。
REM
REM 变量名保持与改造前一致（cmake / ninja / toolchain / msbuild /
REM strip / readelf / androidParam），genSDK.bat、opencvBuild.bat 无需改动。
REM ============================================================

for /f "usebackq delims=" %%i in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\ps\env_paths.ps1" -Batch`) do %%i

if not defined cmake (
    echo [ERROR] Failed to load paths.json via ps\env_paths.ps1
    exit /b 1
)
if not defined toolchain (
    echo [ERROR] toolchain not defined (paths.json / env_paths.ps1 broken^)
    exit /b 1
)
