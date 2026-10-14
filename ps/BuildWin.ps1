param(
    [Parameter(Mandatory = $true)][string]$OutRootWsl,
    [Parameter(Mandatory = $true)][string]$SdkRoot,
    [Parameter(Mandatory = $true)][string]$ThirdPartyDir,
    [Parameter(Mandatory = $true)][string]$LibBaseName,
    [Parameter(Mandatory = $true)][bool]$BuildStatic,
    [string]$winBuildBase = ""
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
#requires -Version 5.1



. (Join-Path $PSScriptRoot "BuildUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration —— 路径来自 ps/env_paths.ps1（真源：config/paths.json），
# BuildUtils.ps1 已经把它 dot-source 进来了，不要在本脚本里写死绝对路径。
$CmakeExe = $cmake
$BuildJobs = 8

if ([string]::IsNullOrWhiteSpace($winBuildBase)) {
    $winBuildBase = Join-Path (Split-Path $SdkRoot -Parent) "build_temp\win"
}

# WSL 路径 -> Windows 路径（转换函数同样只有 env_paths.ps1 一份）
$outRootWin = Get-WinPathFromWsl $OutRootWsl

$win_x64_static = Join-Path $outRootWin "Windows\x64\static"
$win_x64_shared = Join-Path $outRootWin "Windows\x64\shared"
$win_x86_static = Join-Path $outRootWin "Windows\x86\static"
$win_x86_shared = Join-Path $outRootWin "Windows\x86\shared"

function Build-Windows-Arch {
    param($Arch, $StaticFlag, $OutDir)
    Write-Host "`n============================================================"
    Write-Host "Build Windows Arch: $Arch, Static: $StaticFlag"
    Write-Host "============================================================"

    $isStaticStr = if ($StaticFlag) { "ON" } else { "OFF" }
    $buildDir = Join-Path $winBuildBase "win_${Arch}_$isStaticStr"
    Remove-BuildDirectory $buildDir
    Ensure-Directory $OutDir

    $vsArch = if ($Arch -eq "x64") { $vsArchX64 } else { $vsArchX86 }

    # Ensure paths use forward slashes for CMake to avoid escape character issues on Windows
    $cmakeSdkRoot = $SdkRoot -replace '\\', '/'
    $cmakeThirdPartyDir = $ThirdPartyDir -replace '\\', '/'

    # 生成器/架构/静态开关交给 preset（真源 cmake-presets/sdk-presets.json，
    # 源目录里只有一个 include 它的 CMakePresets.json）。-B 仍由本脚本指定，
    # 因为 --preset 之外的 -B 会覆盖 preset 的 binaryDir。
    $mode = "shared"
    if ($StaticFlag) { $mode = "static" }
    $presetName = "win-$Arch-$mode"

    if (Test-CMakePresetAvailable -CmakeExe $CmakeExe -SrcDir $SdkRoot -PresetName $presetName) {
        Write-Host "[preset] ${presetName}  (生成器/架构/静态开关由 preset 提供，build 目录仍由脚本指定)"
        $configureArgs = @(
            "--preset", $presetName,
            "-S", $cmakeSdkRoot,
            "-B", $buildDir,
            "-DTHIRD_PARTY_DIR=$cmakeThirdPartyDir"
        )
    } else {
        Write-Warning "[preset] ${presetName} 不可用，回退到手工参数（源目录没有有效的 CMakePresets.json，或本机缺少对应生成器）"
        $configureArgs = @(
            "-S", $cmakeSdkRoot,
            "-B", $buildDir,
            "-G", $vsGenerator,
            "-A", $vsArch,
            "-DBUILD_STATIC_LIBS=$isStaticStr",
            "-DTHIRD_PARTY_DIR=$cmakeThirdPartyDir"
        )
    }
    Invoke-CMakeConfigure -Arguments $configureArgs -TargetName "Windows $Arch $isStaticStr" -CmakeExe $CmakeExe
    Invoke-CMakeBuild -BuildDir $buildDir -TargetName "Windows $Arch $isStaticStr" -VisualStudio -CmakeExe $CmakeExe

    $releaseDir = Join-Path $buildDir "Release"
    if ($StaticFlag) {
        $lib = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName "$LibBaseName.lib" -Optional
        if ($null -eq $lib) {
            $dll = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName "$LibBaseName.dll" -Optional
            if ($null -ne $dll) {
                Write-Warning "Requested STATIC build but found SHARED library ($LibBaseName.dll). Using it anyway."
                Copy-Artifact -File $dll -OutDir $OutDir
                $lib = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName "$LibBaseName.lib"
                Copy-Artifact -File $lib -OutDir $OutDir
            } else {
                throw "找不到产物: $LibBaseName.lib in $releaseDir"
            }
        } else {
            Copy-Artifact -File $lib -OutDir $OutDir
        }
    } else {
        $dll = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName "$LibBaseName.dll" -Optional
        if ($null -eq $dll) {
            $lib = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName "$LibBaseName.lib" -Optional
            if ($null -ne $lib) {
                Write-Warning "Requested SHARED build but found STATIC library ($LibBaseName.lib). Using it anyway."
                Copy-Artifact -File $lib -OutDir $OutDir
            } else {
                throw "找不到产物: $LibBaseName.dll or $LibBaseName.lib in $releaseDir"
            }
        } else {
            $lib = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName "$LibBaseName.lib"
            Copy-Artifact -File $dll -OutDir $OutDir
            Copy-Artifact -File $lib -OutDir $OutDir
        }
    }
}

try {
    Check-File -Path $CmakeExe -Name "CMake"
    Check-Directory -Path $SdkRoot -Name "Source directory"
    Ensure-Directory $winBuildBase

    # Build Static if requested
    if ($BuildStatic) {
        Build-Windows-Arch -Arch "x64" -StaticFlag $true -OutDir $win_x64_static
        Build-Windows-Arch -Arch "x86" -StaticFlag $true -OutDir $win_x86_static
    }

    # Always Build Shared (per previous script behavior or assuming shared is always needed)
    Build-Windows-Arch -Arch "x64" -StaticFlag $false -OutDir $win_x64_shared
    Build-Windows-Arch -Arch "x86" -StaticFlag $false -OutDir $win_x86_shared

    Write-Host "`n[SUCCESS] Windows builds completed."
} catch {
    Write-Error "Windows build failed: $($_.Exception.Message)"
    exit 1
}
