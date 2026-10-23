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
# copyUtils.ps1：Copy-LibFiles（整组 .so 一起拷），与打包侧共用同一套落点规则
. (Join-Path $PSScriptRoot "copyUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration —— 路径来自 ps/env_paths.ps1（真源：config/paths.json），
# BuildUtils.ps1 已经把它 dot-source 进来了，不要在本脚本里写死绝对路径。
# NDK 版本、ninja、android-28 / c++_shared 这些都在 config/paths.json 里改。
$CmakeExe = $cmake
$NinjaExe = $ninja
$AndroidNdkRoot = $ndkPath
$BuildJobs = 8

if ([string]::IsNullOrWhiteSpace($winBuildBase)) {
    $winBuildBase = Join-Path (Split-Path $SdkRoot -Parent) "build_temp\android"
}

# WSL 路径 -> Windows 路径（转换函数同样只有 env_paths.ps1 一份）
$outRootWin = Get-WinPathFromWsl $OutRootWsl

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

    # 生成器/NDK 工具链/ABI/静态开关交给 preset（真源 cmake-presets/sdk-presets.json）。
    # 注意 preset 里的 NDK 与 ninja 路径是本机绝对路径，换机器要在那边改。
    $mode = "shared"
    if ($StaticFlag) { $mode = "static" }
    $presetName = "android-$Abi-$mode"

    if (Test-CMakePresetAvailable -CmakeExe $CmakeExe -SrcDir $SdkRoot -PresetName $presetName) {
        Write-Host "[preset] ${presetName}  (工具链/ABI/静态开关由 preset 提供，build 目录仍由脚本指定)"
        $configureArgs = @(
            "--preset", $presetName,
            "-S", $cmakeSdkRoot,
            "-B", $buildDir,
            "-DTHIRD_PARTY_DIR=$cmakeThirdPartyDir"
        )
    } else {
        Write-Warning "[preset] ${presetName} 不可用，回退到手工参数（源目录没有有效的 CMakePresets.json）"
        $configureArgs = @(
            "-S", $cmakeSdkRoot, "-B", $buildDir, "-G", "Ninja",
            "-DCMAKE_MAKE_PROGRAM=$NinjaExe", "-DCMAKE_BUILD_TYPE=Release",
            "-DANDROID_STL=$androidStl", "-DANDROID_PLATFORM=$androidPlatform",
            "-DCMAKE_TOOLCHAIN_FILE=$toolchain", "-DANDROID_ABI=$Abi",
            "-DBUILD_STATIC_LIBS=$isStaticStr",
            "-DTHIRD_PARTY_DIR=$cmakeThirdPartyDir"
        )
    }

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

    # 算法库 libFAPAlgo.so 必须与主库同目录（OXiAlgoLoader 从主库自身目录加载），
    # 也必须一起落进构建输出目录 —— 否则 build\<prefix><version>\Android\<abi> 里只有主库，
    # 后续 Sync/打包只能去源码树的构建目录碰运气（IDE 的 cmake-build-* 常常陈旧或未 strip）。
    $nSo = Copy-LibFiles -SrcDir $buildDir -DstDir $OutDir -Kind so
    Write-Host "  [COPY] 运行时库 $nSo 个 .so -> $OutDir"
}

try {
    Check-File -Path $CmakeExe -Name "CMake"
    Check-File -Path $NinjaExe -Name "Ninja"
    Check-Directory -Path $SdkRoot -Name "Source directory"
    Check-Directory -Path $AndroidNdkRoot -Name "Android NDK"
    Ensure-Directory $winBuildBase

    # ABIs to build（列表在 config/paths.json 的 android.abis）
    $abis = $androidAbis

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
