@REM adb shell ip addr show wlan0 > 1.txt
@REM adb kill-server
@REM adb start-server
@REM @echo off
@REM set ip=""
@REM @REM ipconfig >1.txt
@REM for /f "tokens=2 delims= " %%i in ('findstr "global" 1.txt') do set ip=%%i 
@REM @REM del /q 1.txt
@REM @REM pause
@REM @REM echo %ip%
@REM for /f "tokens=1 delims=/" %%i in ("%ip%") do set ip=%%i
@REM echo %ip%
@REM adb tcpip 5555
@REM adb connect %ip%:5555
@REM del 1.txt


@echo off
setlocal EnableDelayedExpansion

echo 获取设备 Wi-Fi IP 并切换到 TCP 模式...

:: 尝试获取 wlan0 的 IP（Android 设备常见接口）
for /f "tokens=2 delims= " %%a in ('adb shell ip addr show wlan0 ^| findstr "inet "') do (
    set "full_ip=%%a"
    goto :extract
)

:: 如果 wlan0 没找到，尝试 eth0 或其他常见接口
for /f "tokens=2 delims= " %%a in ('adb shell ip addr show ^| findstr "inet "') do (
    set "full_ip=%%a"
    goto :extract
)

echo [错误] 无法获取设备 IP，请确认：
echo 1. 设备已通过 USB 连接并开启 USB 调试
echo 2. 设备在同一 Wi-Fi 网络
echo 3. wlan0 接口存在（可以用 adb shell ip addr 检查）
pause
exit /b 1

:extract
:: 提取纯 IP（去掉 /24 等子网掩码）
for /f "tokens=1 delims=/" %%b in ("!full_ip!") do set "ip=%%b"

if "!ip!"=="" (
    echo [错误] 解析 IP 失败
    pause
    exit /b 1
)

echo 设备 IP: !ip!

:: 切换到 TCP 模式并连接
adb tcpip 5555
echo.
echo 正在连接，请稍等 3-5 秒...
adb connect !ip!:5555

echo.
echo 完成！如果看到 "connected to ..." 即成功。
echo 之后可以拔掉 USB 线，使用无线调试。
pause
endlocal