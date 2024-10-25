set SDKDir=D:\git\oxi\g7\FAP70\
set vs64Dir=%SDKDir%cmake-build-release-vs2019_x64\libFAP\Release\
set vs86Dir=%SDKDir%cmake-build-release-vs2019_x86\libFAP\Release\
set winDir=D:\git\oxi\g7\g7010WinDemo\

@REM set androidDir=D:\git\oxi\g6\G6010ASSample\
@REM set linuxDir=%targetDir%\Linux

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
echo %version%