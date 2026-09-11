param(
    [Parameter(Mandatory = $true)][string]$OutRootWsl,
    [Parameter(Mandatory = $true)][string]$SdkRoot,
    [Parameter(Mandatory = $true)][string]$ThirdPartyDir,
    [Parameter(Mandatory = $true)][string]$LibBaseName,
    [Parameter(Mandatory = $true)][bool]$BuildStatic,
    [Parameter(Mandatory = $true)][string]$AndroidProjectRoot,
    [string]$winBuildBase = ""
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
#requires -Version 5.1



. (Join-Path $PSScriptRoot "BuildUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$CmakeExe = "D:\apps\CMake\bin\cmake.exe"
$NinjaExe = "D:\apps\JetBrains\CLion 2023.1.4\bin\ninja\win\x64\ninja.exe"
$AndroidNdkRoot = "D:\apps\Android\Sdk\ndk\28.2.13676358"
$AndroidPlatform = "android-28"
$BuildJobs = 8

if ([string]::IsNullOrWhiteSpace($winBuildBase)) {
    $winBuildBase = Join-Path (Split-Path $SdkRoot -Parent) "build_temp\android"
}

# Convert WSL path -> Windows path
if ($OutRootWsl -match "^/mnt/([a-zA-Z])/(.*)$") {
    $drive = $Matches[1].ToUpper()
    $rest = $Matches[2] -replace '/', '\'
    $outRootWin = "${drive}:\${rest}"
} else {
    $outRootWin = $OutRootWsl -replace '/', '\'
}

$android_arm64 = Join-Path $outRootWin "Android\arm64-v8a"
$android_armv7 = Join-Path $outRootWin "Android\armeabi-v7a"

function Build-Android-Abi {
    param($Abi, $StaticFlag, $OutDir)
    Write-Host "`n============================================================"
    Write-Host "Build Android ABI: $Abi, Static: $StaticFlag"
    Write-Host "============================================================"

    $isStaticStr = if ($StaticFlag) { "ON" } else { "OFF" }
    $buildDir = Join-Path $winBuildBase "android_${Abi}_$isStaticStr"
    Remove-BuildDirectory $buildDir
    Ensure-Directory $OutDir

    $toolchain = Join-Path $AndroidNdkRoot "build\cmake\android.toolchain.cmake"
    Check-File -Path $toolchain -Name "Android CMake Toolchain"

    # Ensure paths use forward slashes for CMake to avoid escape character issues on Windows
    $cmakeSdkRoot = $SdkRoot -replace '\\', '/'
    $cmakeThirdPartyDir = $ThirdPartyDir -replace '\\', '/'

    $configureArgs = @(
        "-S", $cmakeSdkRoot, "-B", $buildDir, "-G", "Ninja",
        "-DCMAKE_MAKE_PROGRAM=$NinjaExe", "-DCMAKE_BUILD_TYPE=Release",
        "-DANDROID_STL=c++_shared", "-DANDROID_PLATFORM=$AndroidPlatform",
        "-DCMAKE_TOOLCHAIN_FILE=$toolchain", "-DANDROID_ABI=$Abi",
        "-DBUILD_STATIC_LIBS=$isStaticStr",
        "-DTHIRD_PARTY_DIR=$cmakeThirdPartyDir"
    )

    Invoke-CMakeConfigure -Arguments $configureArgs -TargetName "Android $Abi $isStaticStr" -CmakeExe $CmakeExe
    Invoke-CMakeBuild -BuildDir $buildDir -TargetName "Android $Abi $isStaticStr" -CmakeExe $CmakeExe

    $libName = if ($StaticFlag) { "lib$LibBaseName.a" } else { "lib$LibBaseName.so" }
    $artifact = Find-Artifact -BuildDir $buildDir -FileName $libName -Optional
    if ($null -eq $artifact) {
        $altLibName = if ($StaticFlag) { "lib$LibBaseName.so" } else { "lib$LibBaseName.a" }
        $artifact = Find-Artifact -BuildDir $buildDir -FileName $altLibName -Optional
        if ($null -ne $artifact) {
            Write-Warning "Requested $($isStaticStr) build but found alternate library ($altLibName). Using it anyway."
        } else {
            throw "找不到产物: $libName (或备选: $altLibName) in $buildDir"
        }
    }
    Copy-Artifact -File $artifact -OutDir $OutDir
}

try {
    Check-File -Path $CmakeExe -Name "CMake"
    Check-File -Path $NinjaExe -Name "Ninja"
    Check-Directory -Path $SdkRoot -Name "Source directory"
    Check-Directory -Path $AndroidNdkRoot -Name "Android NDK"
    Ensure-Directory $winBuildBase

    # ABIs to build
    $abis = @("arm64-v8a", "armeabi-v7a")

    foreach ($abi in $abis) {
        if ($BuildStatic) {
            Build-Android-Abi -Abi $abi -StaticFlag $true -OutDir (Join-Path $outRootWin "Android\$abi")
        }
        # Always build shared
        Build-Android-Abi -Abi $abi -StaticFlag $false -OutDir (Join-Path $outRootWin "Android\$abi")
    }

    Write-Host "`n[SUCCESS] Android native builds completed."
} catch {
    Write-Error "Android build failed: $($_.Exception.Message)"
    exit 1
}
