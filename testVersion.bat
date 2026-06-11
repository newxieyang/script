set cmake=D:\apps\CMake\bin\cmake.exe
set ninja="D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
set projectDir=D:\git\oxi\OXiScan\
set buildDir=D:\output\build

%cmake% -G "Ninja" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10.0 -S %projectDir% -B %buildDir%
IF %errorlevel% neq 0 (
    echo cmake error
    pause
    GOTO END
)
cd %buildDir%

%ninja%
IF %errorlevel% neq 0 (
    echo ninja error
    pause
    GOTO END
)

:END