param(
    [Parameter(Mandatory = $true)][string]$SrcDir,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [Parameter(Mandatory = $true)][string]$CmakeExe,
    [Parameter(Mandatory = $true)][string]$NinjaExe,
    [Parameter(Mandatory = $true)][string]$NdkRoot,
    [Parameter(Mandatory = $true)][string]$AndroidPlatform,
    [int]$BuildJobs = 8
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

. (Join-Path $PSScriptRoot "BuildUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# OpenCV Android Build (arm64-v8a + armeabi-v7a, NDK + Ninja)
#
# Output:
#   libopencv_world.so  (shared, in lib/<abi>/)
# ============================================================

$cmakeSrc = $SrcDir -replace '\\', '/'

function Build-Android-Abi {
    param([string]$Abi, [string]$OutAbiDir)

    $buildDir = Join-Path $SrcDir "build_android_${Abi}"

    Write-Host "`n============================================================"
    Write-Host " Build Android: $Abi"
    Write-Host "============================================================"

    Remove-BuildDirectory $buildDir
    Ensure-Directory $OutAbiDir

    $toolchain = Join-Path $NdkRoot "build\cmake\android.toolchain.cmake"
    Check-File -Path $toolchain -Name "Android CMake Toolchain"

    $configureArgs = @(
        "-S", $cmakeSrc,
        "-B", $buildDir,
        "-G", "Ninja",
        "-DCMAKE_MAKE_PROGRAM=$NinjaExe",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DANDROID_STL=c++_shared",
        "-DANDROID_PLATFORM=$AndroidPlatform",
        "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
        "-DANDROID_ABI=$Abi",
        # --- Core build options ---
        "-DBUILD_SHARED_LIBS=ON",
        "-DBUILD_opencv_world=ON",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_PERF_TESTS=OFF",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_DOCS=OFF",
        "-DBUILD_opencv_apps=OFF",
        # --- IPP / downloads ---
        "-DWITH_IPP=OFF",
        "-DBUILD_IPP_IW=OFF",
        "-DDOWNLOAD_EXTERNAL_TEST_DATA=OFF",
        "-DOPENCV_GENERATE_SETUPVARS=OFF",
        # --- UI backends ---
        "-DWITH_GTK=OFF",
        "-DWITH_QT=OFF",
        # --- Image codecs ---
        "-DWITH_TIFF=OFF",
        "-DWITH_JASPER=OFF",
        "-DWITH_OPENEXR=OFF",
        "-DWITH_WEBP=OFF",
        # --- Video I/O backends ---
        "-DWITH_FFMPEG=OFF",
        "-DWITH_GSTREAMER=OFF",
        "-DWITH_V4L=OFF",
        "-DWITH_1394=OFF",
        "-DWITH_OPENNI=OFF",
        "-DWITH_OPENNI2=OFF",
        # --- Hardware acceleration ---
        "-DWITH_OPENCL=OFF",
        "-DWITH_CUDA=OFF",
        "-DWITH_EIGEN=OFF",
        # --- Module pruning ---
        "-DBUILD_opencv_calib3d=OFF",
        "-DBUILD_opencv_dnn=OFF",
        "-DBUILD_opencv_features2d=OFF",
        "-DBUILD_opencv_flann=OFF",
        "-DBUILD_opencv_gapi=OFF",
        "-DBUILD_opencv_ml=OFF",
        "-DBUILD_opencv_objdetect=OFF",
        "-DBUILD_opencv_photo=OFF",
        "-DBUILD_opencv_stitching=OFF",
        "-DBUILD_opencv_video=OFF",
        # --- Python / Java wrappers ---
        "-DBUILD_opencv_python2=OFF",
        "-DBUILD_opencv_python3=OFF",
        "-DBUILD_opencv_java=OFF",
        "-DBUILD_opencv_js=OFF",
        # --- ARM-specific ---
        "-DCPU_BASELINE=NEON"
    )

    Invoke-CMakeConfigure -Arguments $configureArgs -TargetName "Android $Abi" -CmakeExe $CmakeExe
    Invoke-CMakeBuild -BuildDir $buildDir -TargetName "Android $Abi" -CmakeExe $CmakeExe -BuildJobs $BuildJobs

    # Find libopencv_world.so
    $so = Find-Artifact -BuildDir $buildDir -FileName "libopencv_world.so" -Optional
    if ($null -ne $so) {
        Copy-Artifact -File $so -OutDir $OutAbiDir
    } else {
        # Try versioned name
        $majorMinor = ($Version -split '\.')[0..1] -join '.'
        $versionedSo = Find-Artifact -BuildDir $buildDir -FileName "libopencv_world.so.${majorMinor}" -Optional
        if ($null -ne $versionedSo) {
            # Copy as plain .so
            Ensure-Directory $OutAbiDir
            Copy-Item $versionedSo.FullName (Join-Path $OutAbiDir "libopencv_world.so") -Force
            Write-Host "  [COPY] libopencv_world.so -> $OutAbiDir"
        } else {
            # Search any libopencv_world*.so
            $anySo = Get-ChildItem $buildDir -Recurse -File -Filter "libopencv_world*.so" -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.EndsWith(".debug") } | Select-Object -First 1
            if ($null -ne $anySo) {
                Copy-Item $anySo.FullName (Join-Path $OutAbiDir "libopencv_world.so") -Force
                Write-Host "  [COPY] $($anySo.Name) -> libopencv_world.so -> $OutAbiDir"
            } else {
                throw "libopencv_world.so not found in $buildDir"
            }
        }
    }

    # Copy headers
    $installInclude = Join-Path $buildDir "install\include"
    if (Test-Path $installInclude) {
        $headerOut = Join-Path $OutAbiDir "include"
        Ensure-Directory $headerOut
        Copy-Item "$installInclude\*" $headerOut -Recurse -Force
        Write-Host "  [COPY] include/ -> $headerOut"
    }
}

try {
    Check-File -Path $CmakeExe -Name "CMake"
    Check-File -Path $NinjaExe -Name "Ninja"
    Check-Directory -Path $SrcDir -Name "OpenCV source"
    Check-Directory -Path $NdkRoot -Name "Android NDK"

    $abis = @("arm64-v8a", "armeabi-v7a")

    foreach ($abi in $abis) {
        $abiOut = Join-Path $OutDir $abi
        Build-Android-Abi -Abi $abi -OutAbiDir $abiOut
    }

    Write-Host "`n[SUCCESS] Android builds completed."
} catch {
    Write-Error "Android build failed: $($_.Exception.Message)"
    exit 1
}