echo "copy G7SDK to project"
echo OFF
set targetDir=D:\git\oxi\g7\g7010WinDemo
set platformIndex=%1

@REM set SDKDir=D:\git\oxi\g7\g7demoprogram\

set SDKDir=D:\git\oxi\g7\FAP70\


if %platformIndex% EQU 1 (
	echo "copy win"
    set vs64Dir=%SDKDir%cmake-build-release-vs2019_x64\libFAP\Release\
    set vs86Dir=%SDKDir%cmake-build-release-vs2019_x86\libFAP\Release\

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %targetDir% /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %targetDir% /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %targetDir% /y

    rem copy win_x86
    rem xcopy %vs86Dir%FAP60.dll %targetDir%\libx86 /y
    xcopy %vs86Dir%FAP70.lib %targetDir%\libx86	/y
    xcopy %vs86Dir%FAP70.dll %targetDir%\Release	/y

    rem copy win_x64
    rem xcopy %vs64Dir%FAP60.dll %targetDir%\libx64 /y
    xcopy %vs64Dir%FAP70.lib %targetDir%\libx64 /y
    xcopy %vs64Dir%FAP70.dll %targetDir%\x64\Release /y
)


if %platformIndex% EQU 2 (
    echo "copy android"
    set androidDir=D:\git\oxi\g7\G7010Android\libFAP\src\main\cpp\
    set androidv7Dir=%SDKDir%cmake-build-release-armeabi-v7a\libFAP\
    set androidv8Dir=%SDKDir%cmake-build-release-arm64-v8a\libFAP\

    xcopy %androidv7Dir%libFAP70.so %androidDir%armeabi-v7a /y
    xcopy %androidv8Dir%libFAP70.so %androidDir%arm64-v8a /y

    xcopy %SDKDir%libFAP\include\OXiScanAPI.h %androidDir%include /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimate.h %androidDir%include /y
    xcopy %SDKDir%libFAP\include\OXiScanUltimateApi_err.h %androidDir%include /y
)
echo %time%