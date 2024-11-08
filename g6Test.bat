CHCP 65001
set version=1.6
set targetDir=d:\G6Demo\v%version%
set win86=%targetDir%\win86
set win64=%targetDir%\win64

set SDKDir=D:\git\oxi\g6\G6SDKPlus\jni\
set vs64Dir=%SDKDir%G6SDK\cmake-build-release_x64\Release\
set vs86Dir=%SDKDir%G6SDK\cmake-build-release_x86\Release\

set winDir=D:\git\oxi\g6\g6010WinDemo\

if exist %targetDir% (
   echo "文件存在"
) else (
::创建文件夹
md %targetDir% 
)


if exist %win86% (
   echo "文件存在"
) else (
::创建文件夹
md %win86% 
)


if exist %win64% (
   echo "文件存在"
) else (
::创建文件夹
md %win64% 
)


xcopy D:\git\oxi\g6\G6010ASSample\app\build\outputs\apk\debug\*.apk %targetDir%  /y


xcopy %vs86Dir%FAP60.dll %win86% /y
xcopy %SDKDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x86\onnxruntime.dll %win86% /y
xcopy %winDir%\Release\*.exe %win86% /y

rem copy win_x64
xcopy %vs64Dir%FAP60.dll %win64% /y
xcopy %SDKDir%G6SDK\onnxruntime-1.12.1\lib\vs\win-x64\onnxruntime.dll %win64% /y
xcopy %winDir%\x64\Release\*.exe %win64% /y