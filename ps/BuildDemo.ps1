param (
    [ValidateSet("win", "android", "all")][string]$Kind = "all",
    [string[]]$WinArchs = @("x86", "x64"),
    [string]$DemoWin = "",
    [string]$AndroidProjectRoot = "",
    [string]$AndroidJniDir = "",
    [string]$LibBaseName = "FAP",
    [int]$BuildJobs = 8,
    [switch]$Clean
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

<#
.SYNOPSIS
    重新构建 * _win / *_Android demo 工程（SDK 库同步之后调）。

.DESCRIPTION
    SDK 构建完只把库同步进 demo 的库目录（shared\libx86|libx64、jniLibs）是不够的：
    demo 的 exe / apk 还是上一次编出来的，包里带着的就是旧 exe / 旧 apk。
    本脚本在库同步之后重编 demo，供打包步骤（Copy-WinExe / Copy-AndroidApk）取新产物。

    Windows: 按工程形态分派
             * CMake 工程（A910_win / oxiscansdk_win）：cmake + VS2019 生成器，输出
               cmake-build-release-vs2019_<arch>\，-DFAP_BIN_DIR 指向 demo 自己的库目录
               （CMakeLists 的 POST_BUILD 把整组 dll 部署到 exe 目录）。
             * VS 工程（MIAXIS_win / Thales_win / huantian_win）：msbuild 解决方案
               Release|<x64|Win32>，编完把整组 dll 补到 exe 目录（对齐 CMake 的 POST_BUILD）。
    Android: gradlew assembleDebug，apk 落到 app\build\outputs\apk\debug\。

    demo 固定动态链接（BUILD_STATIC_LIBS=OFF，库目录 shared\lib<arch>），不跟随
    build_static：SDK 侧 BuildWin.ps1 / BuildAndroid.ps1 即使勾了静态库也会**无条件**
    把 shared 产物编出来（Always Build Shared），demo 永远吃得到新鲜的 shared 库。

    库文件被 Copy-Item -Force 覆盖后 mtime 变新 → VS/Gradle 会重新链接/打包，默认不 Clean。
    怀疑产物没更新时加 -Clean 强制全量。

.PARAMETER Kind
    win / android / all（默认 all）

.PARAMETER DemoWin
    Windows demo 源目录（= <sdk_dir>_win）

.PARAMETER AndroidProjectRoot
    Android demo 工程根（= <sdk_dir>_Android，含 gradlew.bat）

.PARAMETER Clean
    构建前删掉构建目录（cmake-build-release-vs2019_* / app\build），强制全量
#>

. (Join-Path $PSScriptRoot "BuildUtils.ps1")
. (Join-Path $PSScriptRoot "copyUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# cmake / msbuild 路径来自 ps/env_paths.ps1（真源 config/paths.json），BuildUtils 已 dot-source
$CmakeExe = $cmake

# demo 固定动态链接，不跟随 build_static（理由见文件头注释）。
$staticStr = "OFF"

function Build-WinDemo {
    param([string]$Arch)

    $platform = if ($Arch -eq "x64") { $vsArchX64 } else { $vsArchX86 }
    # 库目录按 demo 形态判定（CMake → shared\lib<arch>，VS → 工程根 lib<arch>）
    $libDir = Resolve-WinDemoLibDir -DemoWin $DemoWin -Arch $Arch
    $fapLib = Join-Path $libDir "$LibBaseName.lib"

    if (-not (Test-Path -LiteralPath $fapLib -PathType Leaf)) {
        # 库没同步进来就无法链接，别再往下跑（否则链接器报一堆 LNK1104）
        Write-Warning "[跳过] Win $Arch 缺少 $fapLib，先跑库同步再构建 demo"
        return $false
    }

    $isCMake = Test-Path -LiteralPath (Join-Path $DemoWin "CMakeLists.txt") -PathType Leaf
    if ($isCMake) {
        $buildDir = Join-Path $DemoWin "cmake-build-release-vs2019_$Arch"
        if ($Clean -and (Test-Path -LiteralPath $buildDir)) {
            Write-Host "  [CLEAN] 删除构建目录: $buildDir"
            Remove-Item -LiteralPath $buildDir -Recurse -Force
        }

        Write-Host "`n------------------------------------------------------------"
        Write-Host "构建 Demo: Windows $Arch (CMake, BUILD_STATIC_LIBS=$staticStr)"
        Write-Host "  源码目录: $DemoWin"
        Write-Host "  构建目录: $buildDir"
        Write-Host "  库目录  : $libDir"
        Write-Host "------------------------------------------------------------"

        # ⚠️ 不要用 $args 命名（PowerShell 自动变量，指当前作用域未绑定的参数）
        $cmakeArgs = @(
            "-S", $DemoWin,
            "-B", $buildDir,
            "-G", $vsGenerator,
            "-A", $platform,
            "-DBUILD_STATIC_LIBS=$staticStr",
            # CMakeLists 的 POST_BUILD 用 FAP_BIN_DIR 把整组 dll 部署到 exe 目录；
            # 默认值指向 build_temp\win\win-<arch>-shared，与实际产物目录名对不上，这里显式指定。
            "-DFAP_BIN_DIR=$libDir"
        )
        Invoke-CMakeConfigure -Arguments $cmakeArgs -TargetName "Demo Win $Arch" -CmakeExe $CmakeExe
        Invoke-CMakeBuild -BuildDir $buildDir -TargetName "Demo Win $Arch" -VisualStudio -CmakeExe $CmakeExe -BuildJobs $BuildJobs
        return $true
    }

    # VS 工程：vcxproj 已把库目录写死成 .\lib<arch>，直接 msbuild 解决方案
    $sln = @(Get-ChildItem -LiteralPath $DemoWin -Filter "*.sln" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1)
    if ($sln.Count -eq 0) {
        Write-Warning "[跳过] Win $Arch 既没有 CMakeLists.txt 也没有 .sln：$DemoWin"
        return $false
    }

    Write-Host "`n------------------------------------------------------------"
    Write-Host "构建 Demo: Windows $Arch (VS 解决方案, Release|$platform)"
    Write-Host "  解决方案: $($sln[0].FullName)"
    Write-Host "  库目录  : $libDir"
    Write-Host "------------------------------------------------------------"

    $target = if ($Clean) { "Rebuild" } else { "Build" }
    & $msbuild $sln[0].FullName "/t:$target" "/p:Configuration=Release" "/p:Platform=$platform" "/m" "/nologo" "/v:m"
    if ($LASTEXITCODE -ne 0) {
        throw "msbuild 失败（$($sln[0].Name) / Release|$platform），exit=$LASTEXITCODE"
    }

    # 与 CMake demo 的 POST_BUILD 对齐：整组 dll 放到 exe 旁边，否则本地双击起不来
    $exeDir = Resolve-WinDemoDir -SrcDir $DemoWin -Arch $Arch
    if ($exeDir) {
        $n = 0
        foreach ($f in @(Get-ChildItem -LiteralPath $libDir -File -Filter "*.dll" -ErrorAction SilentlyContinue)) {
            if (Copy-FileSafe -SrcFile $f.FullName -DstDir $exeDir) { $n++ }
        }
        if ($n -gt 0) { Write-Host "  [COPY] $n 个 dll -> $exeDir" }
    }
    return $true
}

function Build-AndroidDemo {
    $gradlew = Join-Path $AndroidProjectRoot "gradlew.bat"
    if (-not (Test-Path -LiteralPath $gradlew -PathType Leaf)) {
        Write-Warning "[跳过] Android demo 没有 gradlew.bat: $AndroidProjectRoot"
        return $false
    }
    # jniLibs 就是 lib<Lib>\src\main\cpp\<abi>，库同步到位后 assembleDebug 才会打进 apk。
    # 目录名随机型变（libFAP / libA910 …），没显式给就按 lib*\src\main\cpp 探测。
    $jniRoot = $AndroidJniDir
    if ([string]::IsNullOrWhiteSpace($jniRoot)) {
        $cand = @(Get-ChildItem -LiteralPath $AndroidProjectRoot -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "src\main\cpp") } |
            Select-Object -First 1)
        if ($cand.Count -gt 0) { $jniRoot = Join-Path $cand[0].FullName "src\main\cpp" }
    }
    if (-not $jniRoot -or -not (Test-Path -LiteralPath $jniRoot -PathType Container)) {
        Write-Warning "[跳过] Android demo 没有 jniLibs 目录（lib*\src\main\cpp）: $AndroidProjectRoot"
        return $false
    }

    if ($Clean) {
        foreach ($p in @((Join-Path $AndroidProjectRoot "app\build"),
                         (Join-Path $AndroidProjectRoot "build"))) {
            if (Test-Path -LiteralPath $p) {
                Write-Host "  [CLEAN] 删除构建目录: $p"
                Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host "`n------------------------------------------------------------"
    Write-Host "构建 Demo: Android (assembleDebug)"
    Write-Host "  工程根: $AndroidProjectRoot"
    Write-Host "------------------------------------------------------------"

    Push-Location $AndroidProjectRoot
    try {
        & $gradlew "assembleDebug" "--console=plain"
        if ($LASTEXITCODE -ne 0) {
            throw "gradlew assembleDebug 失败，exit code=$LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
    return $true
}

try {
    $done = 0
    if ($Kind -in @("win", "all")) {
        if ([string]::IsNullOrWhiteSpace($DemoWin)) { throw "Kind=$Kind 时必须提供 -DemoWin" }
        Check-Directory -Path $DemoWin -Name "Windows demo 源目录"
        foreach ($arch in $WinArchs) {
            if (Build-WinDemo -Arch $arch) { $done++ }
        }
    }
    if ($Kind -in @("android", "all")) {
        if ([string]::IsNullOrWhiteSpace($AndroidProjectRoot)) { throw "Kind=$Kind 时必须提供 -AndroidProjectRoot" }
        Check-Directory -Path $AndroidProjectRoot -Name "Android demo 工程根"
        if (Build-AndroidDemo) { $done++ }
    }
    if ($done -eq 0) {
        Write-Warning "[DEMO] 没有任何 demo 被构建（缺库或缺工程），打包会沿用旧产物"
    } else {
        Write-Host "`n[SUCCESS] Demo 构建完成：$done 个目标"
    }
    # 显式 exit 0：调用方（buildOXiAll.ps1）靠 $LASTEXITCODE 判断成败，
    # 不清零的话它拿到的是脚本里最后一条原生命令的退出码（可能是早先 robocopy 的 1）。
    exit 0
} catch {
    Write-Error "Demo build failed: $($_.Exception.Message)"
    exit 1
}
