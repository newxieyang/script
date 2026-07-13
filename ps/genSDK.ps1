<#
.SYNOPSIS
跨平台自动编译脚本，替代原build.bat
Usage:
  .\build.ps1        # 编译 Windows + Android + 复制文件 + 编译Demo
  .\build.ps1 1      # 仅编译 Windows x86/x64
  .\build.ps1 2      # 仅编译 Android armeabi-v7a/arm64-v8a
#>
# ====================== 【配置区域】统一修改路径 ======================
$baseDir = $PSScriptRoot
$projectDir = Join-Path $baseDir "oxiscansdk"
$libName = "FAP"

# 构建目录定义
$winX86Build  = Join-Path $projectDir "cmake-build-release-vs2019_x86"
$winX64Build  = Join-Path $projectDir "cmake-build-release-vs2019_x64"
$armv8Build   = Join-Path $projectDir "cmake-build-release-arm64-v8a"
$armv7Build   = Join-Path $projectDir "cmake-build-release-armeabi-v7a"

# 工具绝对路径
$cmake        = "D:\apps\CMake\bin\cmake.exe"
$ninja        = "D:/apps/JetBrains/CLion 2023.1.4/bin/ninja/win/x64/ninja.exe"
$toolchain    = "D:/apps/Android/Sdk/ndk/25.2.9519653/build/cmake/android.toolchain.cmake"
$msbuild      = "D:\apps\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe"
$llvmStrip    = "D:\apps\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"

# Android CMake公共参数
$androidParams = @(
    "-DCMAKE_BUILD_TYPE=Release",
    "-DANDROID_STL=c++_shared",
    "-DANDROID_PLATFORM=android-28",
    "-DCMAKE_TOOLCHAIN_FILE=`"$toolchain`"",
    "-DCMAKE_MAKE_PROGRAM=`"$ninja`"",
    "-G", "Ninja"
)
$cpuJobCount = 14
# =====================================================================

# 全局错误中断
$ErrorActionPreference = "Stop"

# ---------------------- 函数定义 ----------------------
function Invoke-CheckExitCode {
    param()
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[FATAL] 工具执行失败，退出码: $LASTEXITCODE" -ForegroundColor Red
        Read-Host "按回车退出"
        exit $LASTEXITCODE
    }
}

function Invoke-CopyFile {
    param(
        [string]$src,
        [string]$dst
    )
    Write-Host "[COPY] $src -> $dst"
    if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
    Copy-Item -Path $src -Destination $dst -Force
    Invoke-CheckExitCode
}

function Build-Android {
    Write-Host "`n[INFO] 开始编译Android armeabi-v7a / arm64-v8a" -ForegroundColor Cyan
    foreach ($abi in @("armeabi-v7a", "arm64-v8a")) {
        $buildDir = Join-Path $projectDir "cmake-build-release-$abi"
        # 清理旧构建目录
        if (Test-Path $buildDir) {
            Write-Host "[CLEAN] 删除旧目录 $buildDir"
            Remove-Item -Path $buildDir -Recurse -Force
        }
        # CMake Configure
        Write-Host "[CMAKE] 配置 $abi"
        & $cmake @androidParams "-DANDROID_ABI=$abi" "-S" "`"$projectDir`"" "-B" "`"$buildDir`""
        Invoke-CheckExitCode

        # 编译目标库
        Write-Host "[BUILD] 编译 $abi lib$libName.so"
        & $cmake --build "`"$buildDir`"" --target $libName -j $cpuJobCount
        Invoke-CheckExitCode

        # strip 精简符号
        $soPath = Join-Path $buildDir "lib$libName.so"
        Write-Host "[STRIP] 精简 $soPath"
        & $llvmStrip --strip-unneeded --strip-debug "`"$soPath`""
        Invoke-CheckExitCode
    }
    Write-Host "[OK] Android全部架构编译完成`n" -ForegroundColor Green
}

function Build-Windows {
    Write-Host "`n[INFO] 开始编译Windows x86 / x64" -ForegroundColor Cyan
    $archMap = @{
        "x86"  = "Win32"
        "x64"  = "x64"
    }
    foreach ($winArch in $archMap.Keys) {
        $vsArch = $archMap[$winArch]
        $buildDir = Join-Path $projectDir "cmake-build-release-vs2019_$winArch"
        if (Test-Path $buildDir) {
            Write-Host "[CLEAN] 删除旧目录 $buildDir"
            Remove-Item -Path $buildDir -Recurse -Force
        }
        # CMake VS生成
        Write-Host "[CMAKE] 配置 Windows $winArch ($vsArch)"
        & $cmake -G "Visual Studio 16 2019" -A $vsArch -S "`"$projectDir`"" -B "`"$buildDir`""
        Invoke-CheckExitCode

        # MSBuild编译Release
        Write-Host "[BUILD] 编译 Windows $winArch Release"
        & $cmake --build "`"$buildDir`"" --target $libName --config Release -j $cpuJobCount
        Invoke-CheckExitCode
    }
    Write-Host "[OK] Windows全部架构编译完成`n" -ForegroundColor Green
}

function Copy-OutputFiles {
    Write-Host "`n[INFO] 复制导出头文件" -ForegroundColor Cyan
    $srcHeader = Join-Path $projectDir "base\export\OXiScan_Api.h"
    $dstDir    = Join-Path $baseDir "winSimpleCode"
    Invoke-CopyFile -src $srcHeader -dst $dstDir
    # 如需复制更多文件，在此处追加 Invoke-CopyFile
}

function Build-Demos {
    Write-Host "`n[INFO] 编译Android Demo Gradle & Windows Demo sln" -ForegroundColor Cyan
    # Android Demo gradle assembleDebug
    Push-Location (Join-Path $baseDir "ScannerSimple")
    & .\gradlew.bat assembleDebug
    Invoke-CheckExitCode
    Pop-Location

    # Windows Demo x64 + x86 Release
    $winSln = Join-Path $baseDir "winSimpleCode\GSerLibWin.sln"
    Write-Host "[MSBuild] 编译WinDemo x64 Release"
    & $msbuild "`"$winSln`"" /p:Configuration=Release /p:Platform=x64
    Invoke-CheckExitCode

    Write-Host "[MSBuild] 编译WinDemo x86 Release"
    & $msbuild "`"$winSln`"" /p:Configuration=Release /p:Platform=x86
    Invoke-CheckExitCode
}

function Build-All {
    Build-Android
    Build-Windows
    Copy-OutputFiles
    Build-Demos
}

# ---------------------- 入口参数分发逻辑 ----------------------
$arg = $args[0]
if ($null -eq $arg -or $arg -eq "") {
    Build-All
}
elseif ($arg -eq "1") {
    Build-Windows
}
elseif ($arg -eq "2") {
    Build-Android
}
else {
    Write-Host "[ERROR] 非法入参！`n使用方式：`n  .\build.ps1     全平台编译`n  .\build.ps1 1   仅Windows`n  .\build.ps1 2   仅Android" -ForegroundColor Red
    Read-Host "回车退出"
    exit 1
}

Write-Host "`n==================== 全部构建任务执行完成 ====================" -ForegroundColor Green
Read-Host "按回车键关闭窗口"