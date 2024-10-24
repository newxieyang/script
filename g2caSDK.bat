

set G2ProjectDir=D:\git\oxi\g2\G2SDK1
set outputDir=%G2ProjectDir%\libs
set G2AndroidDir=D:\git\oxi\g2\G2Sample\libFAP\src\main\cpp
set projectDir=%G2ProjectDir%\jni\OXIScanAPI

xcopy %outputDir% %G2AndroidDir% /e /y
xcopy %projectDir%\include\OXiScanAPI.h %G2AndroidDir%\include /y
xcopy %projectDir%\include\OXiScanUltimateApi_err.h %G2AndroidDir%\include /y