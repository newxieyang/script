# 一键构建 Android/Windows 动态库 + 静态库
# 输出到 D:\GserSDK\<版本号>\
#
# 用法:
#   .\SDK2.ps1              # 全平台
#   .\SDK2.ps1 1            # 仅 Windows
#   .\SDK2.ps1 2            # 仅 Android
#   .\SDK2.ps1 -Version 2.0.1.7
param(
    [string]$Version = ""
)

# 公共路径配置（真源：仓库根 paths.json）。param 必须在脚本第一条语句，所以放它后面。
. (Join-Path $PSScriptRoot "env_paths.ps1")

# ====================== 配置区域 ======================
$baseDir      = "D:\git\oxi\shenzhen\"
$projectDir   = Join-Path $baseDir "oxiscansdk"
$libName      = "FAP"


$outputRoot   = "D:\GserSDK"

$androidParams = @(
    "-DCMAKE_BUILD_TYPE=Release",
    "-DANDROID_STL=c++_shared",
    "-DANDROID_PLATFORM=android-28",
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
    "-DCMAKE_MAKE_PROGRAM=$ninja",
    "-G", "Ninja"
)

$cpuJobCount = 14
$ErrorActionPreference = "Stop"
# ======================================================

function Invoke-CheckExitCode {
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "[FATAL] 命令失败，退出码: $LASTEXITCODE" -ForegroundColor Red
        Read-Host "按回车退出"
        exit $LASTEXITCODE
    }
}

function Get-SDKVersion {
    if ($Version -ne "") {
        return $Version
    }
   $versionFile = Join-Path $projectDir "version.cmake"
    if (-not (Test-Path $versionFile)) {
        return "2.0.1.7"
    }

    $content = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) {
        return "2.0.1.7"
    }

    $major = "0"
    $minor = "0"
    $patch = "0"
    $build = "0"

    if ($content -match 'FAP_VERSION_MAJOR\s+(\d+)') {
        $major = $Matches[1]
    }
    if ($content -match 'FAP_VERSION_MINOR\s+(\d+)') {
        $minor = $Matches[1]
    }
    if ($content -match 'FAP_VERSION_PATCH\s+(\d+)') {
        $patch = $Matches[1]
    }
    if ($content -match 'FAP_VERSION_BUILD\s+(\d+)') {
        $build = $Matches[1]
    }

    return "$major.$minor.$patch.$build"
}

function Ensure-Dir {
    param([string]$path)
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Copy-Lib {
    param(
        [string]$src,
        [string]$dstDir,
        [string]$newName = $null
    )
    if (-not (Test-Path $src)) {
        Write-Host "[WARN] 源文件不存在: $src" -ForegroundColor Yellow
        return
    }
    Ensure-Dir $dstDir
    if ($newName) {
        $dst = Join-Path $dstDir $newName
    } else {
        $dst = Join-Path $dstDir (Split-Path $src -Leaf)
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "[COPY] $src -> $dst"
}

function Build-Android {
    param([string]$outDir)

    Write-Host ""
    Write-Host "========== 开始编译 Android ==========" -ForegroundColor Cyan

    $abis = @("armeabi-v7a", "arm64-v8a")
    $types = @(
        @{ Name = "shared"; Static = "OFF" },
        @{ Name = "static"; Static = "ON" }
    )

    foreach ($abi in $abis) {
        foreach ($type in $types) {
            $buildDir = Join-Path $projectDir ("cmake-build-release-" + $abi + "-" + $type.Name)

            if (Test-Path $buildDir) {
                Write-Host "[CLEAN] $buildDir"
                Remove-Item -Path $buildDir -Recurse -Force
            }

            Write-Host ("[CMAKE] Android " + $abi + " " + $type.Name)
            & $cmake @androidParams "-DANDROID_ABI=$abi" "-DBUILD_STATIC_LIBS=$($type.Static)" "-S" $projectDir "-B" $buildDir
            Invoke-CheckExitCode

            Write-Host ("[BUILD] Android " + $abi + " " + $type.Name)
            & $cmake --build $buildDir --target $libName -j $cpuJobCount
            Invoke-CheckExitCode

            if ($type.Name -eq "shared") {
                $libFile = Join-Path $buildDir ("lib" + $libName + ".so")
            } else {
                $libFile = Join-Path $buildDir ("lib" + $libName + ".a")
            }

            if (($type.Name -eq "shared") -and (Test-Path $libFile)) {
                Write-Host "[STRIP] $libFile"
                & $llvmStrip --strip-unneeded --strip-debug $libFile
                Invoke-CheckExitCode
            }

            $dstDir = Join-Path $outDir ("Android\" + $type.Name + "\" + $abi)
            Copy-Lib -src $libFile -dstDir $dstDir
        }
    }
    Write-Host "[OK] Android 全部完成" -ForegroundColor Green
}

function Build-Windows {
    param([string]$outDir)

    Write-Host ""
    Write-Host "========== 开始编译 Windows ==========" -ForegroundColor Cyan

    $archMap = @{
        "x86" = "Win32"
        "x64" = "x64"
    }

    $types = @(
        @{ Name = "shared"; Static = "OFF" },
        @{ Name = "static"; Static = "ON" }
    )

    foreach ($winArch in $archMap.Keys) {
        $vsArch = $archMap[$winArch]

        foreach ($type in $types) {
            $buildDir = Join-Path $projectDir ("cmake-build-release-vs2019_" + $winArch + "_" + $type.Name)

            if (Test-Path $buildDir) {
                Write-Host "[CLEAN] $buildDir"
                Remove-Item -Path $buildDir -Recurse -Force
            }

            Write-Host ("[CMAKE] Windows " + $winArch + " " + $type.Name)
            & $cmake -G "Visual Studio 16 2019" -A $vsArch "-DBUILD_STATIC_LIBS=$($type.Static)" -S $projectDir -B $buildDir
            Invoke-CheckExitCode

            Write-Host ("[BUILD] Windows " + $winArch + " " + $type.Name + " Release")
            & $cmake --build $buildDir --target $libName --config Release -j $cpuJobCount
            Invoke-CheckExitCode

            $dstDir = Join-Path $outDir ("Windows\" + $type.Name + "\" + $winArch)

            if ($type.Name -eq "shared") {
                $dll = Join-Path $buildDir ("Release\" + $libName + ".dll")
                $lib = Join-Path $buildDir ("Release\" + $libName + ".lib")
                Copy-Lib -src $dll -dstDir $dstDir
                Copy-Lib -src $lib -dstDir $dstDir
            } else {
                $lib = Join-Path $buildDir ("Release\" + $libName + ".lib")
                Copy-Lib -src $lib -dstDir $dstDir
            }
        }
    }
    Write-Host "[OK] Windows 全部完成" -ForegroundColor Green
}

function Copy-Headers {
    param([string]$outDir)

    Write-Host ""
    Write-Host "[INFO] 复制头文件" -ForegroundColor Cyan
    $headerSrc = Join-Path $projectDir "base\export\OXiScan_Api.h"
    $headerDst = Join-Path $outDir "include"
    Copy-Lib -src $headerSrc -dstDir $headerDst
}

# ---------------------- 主流程 ----------------------
$sdkVer = Get-SDKVersion
$outDir = Join-Path $outputRoot $sdkVer

Write-Host "========================================" -ForegroundColor Green
Write-Host " SDK Version : $sdkVer"
Write-Host " Output Dir  : $outDir"
Write-Host "========================================" -ForegroundColor Green

Ensure-Dir $outDir

$arg = $args[0]
if (($null -eq $arg) -or ($arg -eq "")) {
    Build-Android -outDir $outDir
    Build-Windows -outDir $outDir
}
elseif ($arg -eq "1") {
    Build-Windows -outDir $outDir
}
elseif ($arg -eq "2") {
    Build-Android -outDir $outDir
}
else {
    Write-Host "[ERROR] 非法参数" -ForegroundColor Red
    Write-Host "用法:"
    Write-Host "  .\SDK2.ps1          全平台"
    Write-Host "  .\SDK2.ps1 1        仅Windows"
    Write-Host "  .\SDK2.ps1 2        仅Android"
    exit 1
}

Copy-Headers -outDir $outDir

Write-Host ""
Write-Host "==================== 构建完成 ====================" -ForegroundColor Green
Write-Host "输出目录: $outDir"
Write-Host "目录结构:"
Write-Host "  include\OXiScan_Api.h"
Write-Host "  Android\shared\armeabi-v7a\libFAP.so"
Write-Host "  Android\shared\arm64-v8a\libFAP.so"
Write-Host "  Android\static\armeabi-v7a\libFAP.a"
Write-Host "  Android\static\arm64-v8a\libFAP.a"
Write-Host "  Windows\shared\x86\FAP.dll + FAP.lib"
Write-Host "  Windows\shared\x64\FAP.dll + FAP.lib"
Write-Host "  Windows\static\x86\FAP.lib"
Write-Host "  Windows\static\x64\FAP.lib"
Read-Host "按回车键关闭"