adb shell ip addr show wlan0 > 1.txt
adb kill-server
adb start-server
@echo off
set ip=""
@REM ipconfig >1.txt
for /f "tokens=2 delims= " %%i in ('findstr "global" 1.txt') do set ip=%%i 
@REM del /q 1.txt
@REM pause
@REM echo %ip%
for /f "tokens=1 delims=/" %%i in ("%ip%") do set ip=%%i
echo %ip%
adb tcpip 5555
adb connect %ip%:5555
del 1.txt