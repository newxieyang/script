
param (
    [string]$ConfigKey = "OPENCV",
    [string]$ConfigFile = "D:\git\script\ps\opencv_config.json"
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

<#
.SYNOPSIS
    OpenCV Multi-Platform Build Script
    Targets: Linux (x64/ARM64 via WSL), Windows (x86/x64), Android (arm64-v8a/armeabi-v7a)

.DESCRIPTION
    Config-driven orchestrator. Reads opencv_config.json, dispatches to
    platform-specific sub-scripts, collects all artifacts into a unified
    output directory.

.NOTES
    Linux build delegates to shell/opencv-wsl.sh (passing version as $1).
    Ensure opencv-wsl.sh has been parameterized to accept the version argument.
#>

. (Join-Path $PSScriptRoot "BuildUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# 1. Load Configuration
# ============================================================
if (-not (Test-Path $ConfigFile)) {
    throw "Configuration file not found: $ConfigFile"
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
if (-not $config.PSObject.Properties[$ConfigKey]) {
    throw "Config key '$ConfigKey' not found in config file."
}

$cfg = $config.$ConfigKey

# ============================================================
# 2. Parse Configuration
# ============================================================
$Version       = $cfg.version
$SrcDir        = $cfg.src_dir -replace '/', '\'
$OutputRoot    = $cfg.output_root -replace '/', '\'
$BuildLinux    = [bool]$cfg.build_linux
$BuildWindows  = [bool]$cfg.build_windows
$BuildAndroid  = [bool]$cfg.build_android

$WslScript     = $cfg.wsl_script
$WslGccX64     = $cfg.wsl_gcc_x64
$WslGccArm64   = $cfg.wsl_gcc_arm64

$WinCmake      = $cfg.win_cmake -replace '/', '\'
$WinVsGen      = $cfg.win_vs_generator

$AndroidNdk    = $cfg.android_ndk -replace '/', '\'
$AndroidPlatform = $cfg.android_platform
$AndroidNinja  = $cfg.android_ninja -replace '/', '\'
$AndroidCmake  = $WinCmake

# Version suffix for Windows DLL naming (4.6.0 -> 460, 4.10.0 -> 4100)
$VersionSuffix = $Version -replace '\.', ''

# Derived paths
$OutDir = Join-Path $OutputRoot "opencv-$Version"

# WSL script output (opencv-wsl.sh creates opencv_release/ under src dir)
$WslReleaseDir = Join-Path $SrcDir "opencv_release"

# Sub-scripts
$BuildWinScript     = Join-Path $PSScriptRoot "BuildOpenCVWin.ps1"
$BuildAndroidScript = Join-Path $PSScriptRoot "BuildOpenCVAndroid.ps1"

# ============================================================
# 3. Print Build Plan
# ============================================================
$totalSteps = 1  # final collection
if ($BuildLinux)   { $totalSteps++ }
if ($BuildWindows) { $totalSteps++ }
if ($BuildAndroid) { $totalSteps++ }
$stepNum = 0

Write-Host "`n============================================================"
Write-Host " OpenCV Multi-Platform Build"
Write-Host " Version:    $Version (suffix: $VersionSuffix)"
Write-Host " Source:     $SrcDir"
Write-Host " Output:     $OutDir"
Write-Host " Platforms:  $(if ($BuildLinux) {'Linux '})$(if ($BuildWindows) {'Windows '})$(if ($BuildAndroid) {'Android'})"
Write-Host "============================================================`n"

$startTime = Get-Date

# ============================================================
# 4. Build Linux (WSL)
# ============================================================
if ($BuildLinux) {
    $stepNum++
    Write-Host "[$stepNum/$totalSteps] Building Linux via WSL (x64 + ARM64)..."

    $wslSrcDir = Get-WslPath $SrcDir
    $wslOutDir = Get-WslPath $OutDir

    # Pass version + source path as environment variables to WSL.
    # opencv-wsl.sh should read OPENCV_VERSION (with fallback to 4.6.0).
    wsl bash -c "OPENCV_VERSION='$Version' bash $WslScript '$Version'"

    if ($LASTEXITCODE -ne 0) {
        throw "Linux (WSL) build failed, exit code=$LASTEXITCODE"
    }

    # Collect artifacts from WSL output
    $linuxOut = Join-Path $OutDir "Linux"
    Ensure-Directory (Join-Path $linuxOut "x64")
    Ensure-Directory (Join-Path $linuxOut "arm")

    $x64So = Join-Path $WslReleaseDir "x64\lib\libopencv_world.so"
    $armSo = Join-Path $WslReleaseDir "arm\lib\libopencv_world.so"

    if (Test-Path $x64So) {
        Copy-Item $x64So (Join-Path $linuxOut "x64\libopencv_world.so") -Force
        Write-Host "  [COPY] libopencv_world.so (x64) -> Linux\x64\"
    } else {
        Write-Warning "Linux x64 artifact not found: $x64So"
    }

    if (Test-Path $armSo) {
        Copy-Item $armSo (Join-Path $linuxOut "arm\libopencv_world.so") -Force
        Write-Host "  [COPY] libopencv_world.so (arm) -> Linux\arm\"
    } else {
        Write-Warning "Linux arm artifact not found: $armSo"
    }

} else {
    Write-Host "Skipping Linux build."
}

# ============================================================
# 5. Build Windows
# ============================================================
if ($BuildWindows) {
    $stepNum++
    Write-Host "`n[$stepNum/$totalSteps] Building Windows (x64 + x86)..."

    & $BuildWinScript `
        -SrcDir $SrcDir `
        -Version $Version `
        -VersionSuffix $VersionSuffix `
        -OutDir (Join-Path $OutDir "Windows") `
        -CmakeExe $WinCmake `
        -VsGenerator $WinVsGen

    if ($LASTEXITCODE -ne 0) {
        throw "Windows build failed, exit code=$LASTEXITCODE"
    }

} else {
    Write-Host "`nSkipping Windows build."
}

# ============================================================
# 6. Build Android
# ============================================================
if ($BuildAndroid) {
    $stepNum++
    Write-Host "`n[$stepNum/$totalSteps] Building Android (arm64-v8a + armeabi-v7a)..."

    & $BuildAndroidScript `
        -SrcDir $SrcDir `
        -Version $Version `
        -OutDir (Join-Path $OutDir "Android") `
        -CmakeExe $AndroidCmake `
        -NinjaExe $AndroidNinja `
        -NdkRoot $AndroidNdk `
        -AndroidPlatform $AndroidPlatform

    if ($LASTEXITCODE -ne 0) {
        throw "Android build failed, exit code=$LASTEXITCODE"
    }

} else {
    Write-Host "`nSkipping Android build."
}

# ============================================================
# 7. Final Package Summary
# ============================================================
$stepNum++
Write-Host "`n[$stepNum/$totalSteps] Build artifacts summary..."

Write-Host "`n============================================================"
Write-Host " Output directory: $OutDir"
Write-Host "============================================================"

function Show-Artifacts {
    param([string]$Label, [string]$Path)
    if (Test-Path $Path) {
        Write-Host "`n  $Label:"
        Get-ChildItem $Path -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($Path.Length)
            Write-Host "    $rel  ($('{0:N1}' -f ($_.Length/1KB)) KB)"
        }
    }
}

if ($BuildLinux)   { Show-Artifacts "Linux"   (Join-Path $OutDir "Linux") }
if ($BuildWindows) { Show-Artifacts "Windows" (Join-Path $OutDir "Windows") }
if ($BuildAndroid) { Show-Artifacts "Android" (Join-Path $OutDir "Android") }

# ============================================================
# 8. Complete
# ============================================================
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "`n============================================================"
Write-Host " ALL TASKS COMPLETED SUCCESSFULLY"
Write-Host " Version:  $Version"
Write-Host " Duration: $($duration.TotalSeconds.ToString('F1')) seconds"
Write-Host "============================================================`n"