echo off


set customStr=ARATEK
set sourceDir=D:\git\oxi\g6\
set SDKDir=%sourceDir%FAP6010_%customStr%\
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

set targetDir=D:\G6SDKLib\%customStr%\G6SDKtestv%version%mk%mkVerStr%
set zipFilePathName=%targetDir%.zip

echo %targetDir%
echo %zipFilePathName%