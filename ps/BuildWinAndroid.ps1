#requires -Version 5.1

<#
.SYNOPSIS
    Build OXiScan Windows + Android SDK

.EXAMPLE
    .\BuildWinAndroid.ps1 -OutRootWsl "/mnt/d/git/oxi/shenzhen/build/OXiScanV9.9.9.9"

.NOTES
    Windows:
        x64 Static
        x64 Shared
        x86 Static
        x86 Shared

    Android:
        arm64-v8a Static
        arm64-v8a Shared
        armeabi-v7a Static
        armeabi-v7a Shared
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OutRootWsl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# Configuration
# ============================================================
$CmakeExe = "D:\apps\CMake\bin\cmake.exe"
$NinjaExe = "D:\apps\JetBrains\CLion 2023.1.4\bin\ninja\win\x64\ninja.exe"
$AndroidNdkRoot = "D:\apps\Android\Sdk\ndk\28.2.13676358"
$basedir = "D:\git\oxi\shenzhen\oxiscansdk"

# Windows 临时构建目录
$winBuildBase = "D:\git\oxi\shenzhen\build_temp"

# Android
$AndroidPlatform = "android-28"

# ============================================================
# Android APK
# ============================================================
$AndroidProjectRoot = "D:\git\oxi\shenzhen\oxiscansdk_Android"
$AndroidVersionFile = Join-Path $AndroidProjectRoot "gradle\libs.versions.toml"

# 并行编译线程
$BuildJobs = 8


# ============================================================
# Convert WSL path -> Windows path
# ============================================================

if ([string]::IsNullOrWhiteSpace($OutRootWsl)) {
    throw "OutRootWsl 不能为空"
}

$outRootWin = $OutRootWsl

if ($outRootWin -match "^/mnt/([a-zA-Z])/(.*)$") {
    $drive = $Matches[1].ToUpper()
    $rest = $Matches[2] -replace '/', '\'
    $outRootWin = "${drive}:\${rest}"
}
else {
    $outRootWin = $outRootWin -replace '/', '\'
}


# ============================================================
# Output directories
# ============================================================

$win_x64_static = Join-Path $outRootWin "Windows\x64\static"
$win_x64_shared = Join-Path $outRootWin "Windows\x64\shared"

$win_x86_static = Join-Path $outRootWin "Windows\x86\static"
$win_x86_shared = Join-Path $outRootWin "Windows\x86\shared"

$android_arm64 = Join-Path $outRootWin "Android\arm64-v8a"
$android_armv7 = Join-Path $outRootWin "Android\armeabi-v7a"


$apkOutDir = Join-Path $outRootWin "APK"
New-Item -ItemType Directory -Force -Path $apkOutDir | Out-Null

# ============================================================
# Helper functions
# ============================================================
function Check-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "${Name} 不存在: ${Path}"
    }

    Write-Host "[OK] ${Name}: ${Path}"
}


function Check-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "${Name} 不存在: ${Path}"
    }

    Write-Host "[OK] ${Name}: ${Path}"
}


function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}


function Remove-BuildDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Write-Host "Cleaning build directory:"
        Write-Host "  ${Path}"
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }

    New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null

    # 验证目录可写
    $testFile = Join-Path $Path "__write_test.tmp"

    try {
        "test" | Set-Content -LiteralPath $testFile -Encoding ASCII -ErrorAction Stop
        Remove-Item -LiteralPath $testFile -Force -ErrorAction Stop
    }
    catch {
        throw "Build directory 不可写: ${Path}`n$($_.Exception.Message)"
    }
}


function Invoke-CMakeConfigure {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "CMake Configure: ${TargetName}"
    Write-Host "------------------------------------------------------------"

    & $CmakeExe @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "CMake configure failed: ${TargetName}, exit code=${exitCode}"
    }
    Write-Host "[OK] CMake configure: ${TargetName}"
}


function Invoke-CMakeBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildDir,

        [Parameter(Mandatory = $true)]
        [string]$TargetName,

        [switch]$VisualStudio
    )

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "CMake Build: ${TargetName}"
    Write-Host "------------------------------------------------------------"

    if ($VisualStudio) {
        & $CmakeExe --build $BuildDir --config Release --parallel $BuildJobs
    }
    else {
        & $CmakeExe --build $BuildDir --parallel $BuildJobs
    }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "CMake build failed: ${TargetName}, exit code=${exitCode}"
    }
    Write-Host "[OK] CMake build: ${TargetName}"
}


function Find-Artifact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildDir,

        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [string]$SearchDir
    )

    if ([string]::IsNullOrWhiteSpace($SearchDir)) {
        $SearchDir = $BuildDir
    }

    if (-not (Test-Path -LiteralPath $SearchDir -PathType Container)) {
        throw "搜索目录不存在: ${SearchDir}"
    }

    $file = Get-ChildItem -LiteralPath $SearchDir -Recurse -File -Filter $FileName -ErrorAction Stop | Select-Object -First 1

    if ($null -eq $file) {
        throw "构建成功，但找不到产物 ${FileName}`nBuildDir: ${BuildDir}`nSearchDir: ${SearchDir}"
    }

    if ($file.Length -le 0) {
        throw "产物为空文件: ${file.FullName}"
    }

    return $file
}


function Copy-Artifact {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [string]$OutDir
    )

    Ensure-Directory $OutDir
    $destination = Join-Path $OutDir $File.Name
    Copy-Item -LiteralPath $File.FullName -Destination $destination -Force -ErrorAction Stop

    Write-Host "[COPY] $($File.Name)"
    Write-Host "       FROM: $($File.FullName)"
    Write-Host "       TO  : ${destination}"

    return $destination
}


# ============================================================
# Build Windows
# ============================================================

function BuildWin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Arch,

        [Parameter(Mandatory = $true)]
        [ValidateSet("ON", "OFF")]
        [string]$IsStatic,

        [Parameter(Mandatory = $true)]
        [string]$OutDir
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Build Windows"
    Write-Host "  Architecture : ${Arch}"
    Write-Host "  Static       : ${IsStatic}"
    Write-Host "  Output       : ${OutDir}"
    Write-Host "============================================================"

    $buildDir = Join-Path $winBuildBase "win_${Arch}_${IsStatic}"
    Remove-BuildDirectory $buildDir
    Ensure-Directory $OutDir

    if ($Arch -eq "x64") {
        $vsArch = "x64"
    }
    elseif ($Arch -eq "x86") {
        $vsArch = "Win32"
    }
    else {
        throw "不支持的 Windows 架构: ${Arch}"
    }


    # --------------------------------------------------------
    # CMake Configure
    # --------------------------------------------------------

    $configureArgs = @(
        "-S", $basedir,
        "-B", $buildDir,
        "-G", "Visual Studio 16 2019",
        "-A", $vsArch,
        "-DBUILD_STATIC_LIBS=${IsStatic}"
    )

    Invoke-CMakeConfigure `
        -Arguments $configureArgs `
        -TargetName "Windows ${Arch} ${IsStatic}"


    # --------------------------------------------------------
    # Build
    # --------------------------------------------------------

    Invoke-CMakeBuild `
        -BuildDir $buildDir `
        -TargetName "Windows ${Arch} ${IsStatic}" `
        -VisualStudio


    # --------------------------------------------------------
    # Find Release artifacts
    # --------------------------------------------------------

    $releaseDir = Join-Path $buildDir "Release"

    if (-not (Test-Path -LiteralPath $releaseDir -PathType Container)) {
        throw "Windows Release 目录不存在: ${releaseDir}"
    }


    if ($IsStatic -eq "ON") {

        $lib = Find-Artifact `
            -BuildDir $buildDir `
            -SearchDir $releaseDir `
            -FileName "FAP.lib"

        Copy-Artifact `
            -File $lib `
            -OutDir $OutDir
    }
    else {

        $dll = Find-Artifact `
            -BuildDir $buildDir `
            -SearchDir $releaseDir `
            -FileName "FAP.dll"

        $lib = Find-Artifact `
            -BuildDir $buildDir `
            -SearchDir $releaseDir `
            -FileName "FAP.lib"

        Copy-Artifact `
            -File $dll `
            -OutDir $OutDir

        Copy-Artifact `
            -File $lib `
            -OutDir $OutDir
    }

    Write-Host "[OK] Windows ${Arch} ${IsStatic}"
}


# ============================================================
# Build Android
# ============================================================

function BuildAndroid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Abi,

        [Parameter(Mandatory = $true)]
        [ValidateSet("ON", "OFF")]
        [string]$IsStatic,

        [Parameter(Mandatory = $true)]
        [string]$OutDir
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Build Android"
    Write-Host "  ABI          : ${Abi}"
    Write-Host "  Static       : ${IsStatic}"
    Write-Host "  Output       : ${OutDir}"
    Write-Host "============================================================"


    # --------------------------------------------------------
    # Build directory
    # --------------------------------------------------------
    $buildDir = Join-Path  $winBuildBase "android_${Abi}_${IsStatic}"
    Remove-BuildDirectory $buildDir
    Ensure-Directory $OutDir

    # --------------------------------------------------------
    # Android Toolchain
    # --------------------------------------------------------
    $toolchain = Join-Path $AndroidNdkRoot "build\cmake\android.toolchain.cmake"
    Check-File -Path $toolchain -Name "Android CMake Toolchain"


    # --------------------------------------------------------
    # CMake Configure
    # --------------------------------------------------------

    $configureArgs = @(
        "-S", $basedir,
        "-B", $buildDir,
        "-G", "Ninja",
        "-DCMAKE_MAKE_PROGRAM=$NinjaExe",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DANDROID_STL=c++_shared",
        "-DANDROID_PLATFORM=$AndroidPlatform",
        "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
        "-DANDROID_ABI=$Abi",
        "-DBUILD_STATIC_LIBS=${IsStatic}"
    )

    Invoke-CMakeConfigure -Arguments $configureArgs -TargetName "Android ${Abi} ${IsStatic}"
    # Build
    Invoke-CMakeBuild  -BuildDir $buildDir  -TargetName "Android ${Abi} ${IsStatic}"


    # Find artifact
    if ($IsStatic -eq "ON") {
        $libName = "libFAP.a"
    }
    else {
        $libName = "libFAP.so"
    }

    $artifact = Find-Artifact -BuildDir $buildDir -FileName $libName
    Copy-Artifact -File $artifact -OutDir $OutDir
    Write-Host "[OK] Android ${Abi} ${IsStatic}"
}


# ============================================================
# Verify output
# ============================================================

function Verify-Output {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "[VERIFY FAILED] ${Description} : ${Path}"
    }

    $file = Get-Item -LiteralPath $Path

    if ($file.Length -le 0) {
        throw "[VERIFY FAILED] ${Description} : ${Path} (empty file)"
    }

    Write-Host "[VERIFY OK] ${Description} : ${Path}"
}


function Verify-AllOutputs {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "VERIFY OUTPUT"
    Write-Host "============================================================"


    # --------------------------------------------------------
    # Windows x64
    # --------------------------------------------------------

    Verify-Output `
        -Path (Join-Path $win_x64_static "FAP.lib") `
        -Description "Windows x64 Static"

    Verify-Output `
        -Path (Join-Path $win_x64_shared "FAP.dll") `
        -Description "Windows x64 Shared DLL"

    Verify-Output `
        -Path (Join-Path $win_x64_shared "FAP.lib") `
        -Description "Windows x64 Shared Import LIB"


    # --------------------------------------------------------
    # Windows x86
    # --------------------------------------------------------

    Verify-Output `
        -Path (Join-Path $win_x86_static "FAP.lib") `
        -Description "Windows x86 Static"

    Verify-Output `
        -Path (Join-Path $win_x86_shared "FAP.dll") `
        -Description "Windows x86 Shared DLL"

    Verify-Output `
        -Path (Join-Path $win_x86_shared "FAP.lib") `
        -Description "Windows x86 Shared Import LIB"


    # --------------------------------------------------------
    # Android arm64-v8a
    # --------------------------------------------------------

    Verify-Output `
        -Path (Join-Path $android_arm64 "libFAP.a") `
        -Description "Android arm64-v8a Static"

    Verify-Output `
        -Path (Join-Path $android_arm64 "libFAP.so") `
        -Description "Android arm64-v8a Shared"


    # --------------------------------------------------------
    # Android armeabi-v7a
    # --------------------------------------------------------

    Verify-Output `
        -Path (Join-Path $android_armv7 "libFAP.a") `
        -Description "Android armeabi-v7a Static"

    Verify-Output `
        -Path (Join-Path $android_armv7 "libFAP.so") `
        -Description "Android armeabi-v7a Shared"


    Write-Host ""
    Write-Host "[VERIFY OK] All Windows + Android artifacts."
}


# ============================================================
# Show summary
# ============================================================

function Show-Summary {

    Write-Host ""
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "BUILD SUMMARY"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "Windows x64 Static:"
    Write-Host "  ${win_x64_static}"

    Write-Host ""
    Write-Host "Windows x64 Shared:"
    Write-Host "  ${win_x64_shared}"

    Write-Host ""
    Write-Host "Windows x86 Static:"
    Write-Host "  ${win_x86_static}"

    Write-Host ""
    Write-Host "Windows x86 Shared:"
    Write-Host "  ${win_x86_shared}"

    Write-Host ""
    Write-Host "Android arm64-v8a:"
    Write-Host "  ${android_arm64}"

    Write-Host ""
    Write-Host "Android armeabi-v7a:"
    Write-Host "  ${android_armv7}"

    Write-Host ""
    Write-Host "============================================================"
}

function Update-AndroidVersion {
    param(
        [string]$VersionFile
    )

    if (-not (Test-Path $VersionFile)) {
        throw "Android version file not found: $VersionFile"
    }

    $content = [System.IO.File]::ReadAllText(
        $VersionFile,
        [System.Text.Encoding]::UTF8
    )

    $pattern = '(?m)^(\s*versionName\s*=\s*")v?(\d+)\.(\d+)\.(\d+)\.(\d+)(".*)$'

    $match = [regex]::Match($content, $pattern)

    if (-not $match.Success) {
        throw "Cannot find versionName in: $VersionFile"
    }

    $major = [int]$match.Groups[2].Value
    $minor = [int]$match.Groups[3].Value
    $patch = [int]$match.Groups[4].Value
    $build = [int]$match.Groups[5].Value

    $oldVersion = "v${major}.${minor}.${patch}.${build}"

    $build++

    $newVersion = "v${major}.${minor}.${patch}.${build}"

    Write-Host ""
    Write-Host "Android APK version:"
    Write-Host "  $oldVersion -> $newVersion"

    $newLine = $match.Groups[1].Value +
               $newVersion +
               $match.Groups[6].Value

    $newContent = [regex]::Replace(
        $content,
        $pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return $newLine
        },
        1
    )

    # UTF-8 without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $VersionFile,
        $newContent,
        $utf8NoBom
    )

    return $newVersion
}


function BuildAndroidApk {
    param(
        [string]$ProjectRoot,
        [string]$OutDir
    )

    # ... (header omitted for brevity) ...

    # 1. Resolve Environment Conflict (Optional but recommended inside script)
    if ($env:ANDROID_PREFS_ROOT) { $env:ANDROID_PREFS_ROOT = $null }

    Push-Location $ProjectRoot
    try {
        Write-Host "Running Gradle assembleDebug..."
        # Using --no-daemon might be slower, removed for performance unless strictly needed
        $gradleOutput = & .\gradlew.bat :app:assembleDebug --stacktrace 2>&1
        $gradleOutput | Write-Host

        if ($LASTEXITCODE -ne 0) {
            throw "Android APK build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    # 2. Updated APK Search Logic: Find *.apk inside the release folder
    $apk = Get-ChildItem -Path "$ProjectRoot\app\build\outputs\apk\release" -Filter "*.apk" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $apk) {
        throw "Release APK not found in expected directory: $ProjectRoot\app\build\outputs\apk\release"
    }

    Write-Host "`nAPK found: $($apk.FullName)"

    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force }
    Copy-Item -Path $apk.FullName -Destination $OutDir -Force

    Write-Host "APK copied to: $OutDir"
}
# ============================================================
# Environment Check
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "OXiScan Windows + Android Build"
Write-Host "============================================================"

Write-Host ""
Write-Host "Source:"
Write-Host "  ${basedir}"

Write-Host ""
Write-Host "Output:"
Write-Host "  ${outRootWin}"

Write-Host ""
Write-Host "Build temp:"
Write-Host "  ${winBuildBase}"

Write-Host ""
Write-Host "Android NDK:"
Write-Host "  ${AndroidNdkRoot}"

Write-Host ""
Write-Host "Android Platform:"
Write-Host "  ${AndroidPlatform}"


# ------------------------------------------------------------
# Check tools
# ------------------------------------------------------------

Check-File -Path $CmakeExe -Name "CMake"
Check-File -Path $NinjaExe -Name "Ninja"
Check-Directory -Path $basedir -Name "Source directory"
Check-Directory -Path $AndroidNdkRoot -Name "Android NDK"


# ------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------

Ensure-Directory $winBuildBase

Ensure-Directory $outRootWin

Ensure-Directory $win_x64_static
Ensure-Directory $win_x64_shared
Ensure-Directory $win_x86_static
Ensure-Directory $win_x86_shared

Ensure-Directory $android_arm64
Ensure-Directory $android_armv7


# ============================================================
# Build
# ============================================================

try {

    # ========================================================
    # Windows
    # ========================================================
    BuildWin -Arch "x64" -IsStatic "ON" -OutDir $win_x64_static
    BuildWin -Arch "x64" -IsStatic "OFF" -OutDir $win_x64_shared
    BuildWin -Arch "x86" -IsStatic "ON" -OutDir $win_x86_static
    BuildWin -Arch "x86" -IsStatic "OFF" -OutDir $win_x86_shared


    # ========================================================
    # Android Native Library
    # ========================================================
    BuildAndroid -Abi "arm64-v8a" -IsStatic "ON" -OutDir $android_arm64
    BuildAndroid -Abi "arm64-v8a" -IsStatic "OFF" -OutDir $android_arm64
    BuildAndroid -Abi "armeabi-v7a" -IsStatic "ON" -OutDir $android_armv7
    BuildAndroid -Abi "armeabi-v7a"  -IsStatic "OFF" -OutDir $android_armv7


    # ============================================================
    # Android APK Version
    # ============================================================
    $apkVersion = Update-AndroidVersion $AndroidVersionFile


    # ============================================================
    # Android APK
    # ============================================================

    # BuildAndroidApk `
    #     $AndroidProjectRoot `
    #     $apkOutDir


    # ============================================================
    # Rename APK
    # ============================================================

    # $apk = Get-ChildItem `
    #     -Path $apkOutDir `
    #     -Filter "*.apk" `
    #     -File |
    #     Select-Object -First 1

    # if ($null -eq $apk) {
    #     throw "APK was not copied to output directory."
    # }

    # $apkName = "OXiScan-${apkVersion}-release.apk"

    # $apkFinal = Join-Path $apkOutDir $apkName

    # if ($apk.FullName -ne $apkFinal) {
    #     Move-Item `
    #         -Path $apk.FullName `
    #         -Destination $apkFinal `
    #         -Force
    # }
    # ========================================================
    # Verify
    # ========================================================

    Verify-AllOutputs


    # ========================================================
    # Summary
    # ========================================================

    Show-Summary

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "BUILD SUCCESS"
    Write-Host "============================================================"
    Write-Host ""
}
catch {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "BUILD FAILED"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host $_.Exception.Message
    Write-Host ""

    exit 1
}