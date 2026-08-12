<#
全局工具路径公共配置
所有编译脚本共用这套环境变量
#>
# CMake
$cmake        = "D:\apps\CMake\bin\cmake.exe"
# Ninja（CLion内置ninja）
$ninja        = "D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
# VS2019 MSBuild
$msbuild      = "D:\apps\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe"


$sdkPath      = "D:/apps/Android/Sdk"
# NDK and target configuration
# $ndkPath      = "D:\apps\Android\Sdk\ndk\25.2.9519653"
# 26.3.11579264
$ndkPath = "D:\apps\Android\Sdk\ndk\26.3.11579264"
# $ndkPath = "D:\apps\Android\Sdk\ndk\28.2.13676358"
# NDK-25 工具链文件
$toolchain    = "$ndkPath/build/cmake/android.toolchain.cmake"
# NDK-r28 strip
$llvmStrip    = "$ndkPath\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"
# llvm-readelf 用于校验so页对齐，一并放这里
$readelf      = "$ndkPath\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe"

# 导出到当前作用域
# Export-Variable cmake,ninja,toolchain,msbuild,llvmStrip,readelf,ndkPath