@echo OFF
set "cmake=D:\apps\CMake\bin\cmake.exe"
set "ninja=D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
set "toolchain=D:/apps/Android/Sdk/ndk/25.2.9519653/build/cmake/android.toolchain.cmake"
set "msbuild=D:\apps\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe"
set "strip=D:\apps\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe "

set "androidParam=-DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_PLATFORM=android-28 -DCMAKE_TOOLCHAIN_FILE=%toolchain% -DCMAKE_MAKE_PROGRAM=%ninja% -G Ninja"




