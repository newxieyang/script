param(
    [Parameter(Mandatory = $true)][string]$SrcDir,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$VersionSuffix,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [Parameter(Mandatory = $true)][string]$CmakeExe,
    [Parameter(Mandatory = $true)][string]$VsGenerator,
    [int]$BuildJobs = 8
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

. (Join-Path $PSScriptRoot "BuildUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# OpenCV Windows Build (x64 + x86, Visual Studio)
#
# Output:
#   opencv_world<ver>.dll  (e.g. opencv_world460.dll)
#   opencv_world<ver>.lib  (e.g. opencv_world460.lib)
# ============================================================

$winX64Out = Join-Path $OutDir "x64"
$winX86Out = Join-Path $OutDir "x86"

$cmakeSrc = $SrcDir -replace '\\', '/'

# World module output names (version-suffixed)
$dllName = "opencv_world${VersionSuffix}.dll"
$libName = "opencv_world${VersionSuffix}.lib"

function Build-Windows-Arch {
    param([string]$Arch, [string]$OutArchDir)

    $vsArch = if ($Arch -eq "x64") { "x64" } else { "Win32" }
    $buildDir = Join-Path $SrcDir "build_win_${Arch}"

    Write-Host "`n============================================================"
    Write-Host " Build Windows: $Arch ($VsGenerator -A $vsArch)"
    Write-Host "============================================================"

    Remove-BuildDirectory $buildDir
    Ensure-Directory $OutArchDir

    $configureArgs = @(
        "-S", $cmakeSrc,
        "-B", $buildDir,
        "-G", $VsGenerator,
        "-A", $vsArch,
        # --- Core build options ---
        "-DBUILD_SHARED_LIBS=ON",
        "-DBUILD_opencv_world=ON",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_PERF_TESTS=OFF",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_DOCS=OFF",
        "-DBUILD_opencv_apps=OFF",
        # --- IPP / downloads ---
        "-DWITH_IPP=OFF",
        "-DBUILD_IPP_IW=OFF",
        "-DDOWNLOAD_EXTERNAL_TEST_DATA=OFF",
        # --- UI backends ---
        "-DWITH_GTK=OFF",
        "-DWITH_QT=OFF",
        "-DWITH_WIN32UI=OFF",
        # --- Image codecs (keep bundled PNG/JPEG for imgcodecs) ---
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
        "-DWITH_MSMF=OFF",
        "-DWITH_MSMF_DXVA=OFF",
        "-DWITH_DSHOW=OFF",
        # --- Hardware acceleration ---
        "-DWITH_OPENCL=OFF",
        "-DWITH_CUDA=OFF",
        "-DWITH_DIRECTX=OFF",
        "-DWITH_EIGEN=OFF",
        "-DWITH_OPENMP=OFF",
        # --- Module pruning: core, imgproc, imgcodecs, videoio, highgui, world ---
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
        "-DBUILD_opencv_js=OFF"
    )

    Invoke-CMakeConfigure -Arguments $configureArgs -TargetName "Windows $Arch" -CmakeExe $CmakeExe
    Invoke-CMakeBuild -BuildDir $buildDir -TargetName "Windows $Arch" -VisualStudio -CmakeExe $CmakeExe -BuildJobs $BuildJobs

    # Collect artifacts from Release folder
    $releaseDir = Join-Path $buildDir "bin\Release"
    if (-not (Test-Path $releaseDir)) {
        $releaseDir = Join-Path $buildDir "Release"
    }

    $dll = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName $dllName -Optional
    if ($null -ne $dll) {
        Copy-Artifact -File $dll -OutDir $OutArchDir
    } else {
        Write-Warning "$dllName not found in $releaseDir"
    }

    $lib = Find-Artifact -BuildDir $buildDir -SearchDir $releaseDir -FileName $libName -Optional
    if ($null -ne $lib) {
        Copy-Artifact -File $lib -OutDir $OutArchDir
    } else {
        Write-Warning "$libName not found in $releaseDir"
    }

    # Also copy headers
    $includeDir = Join-Path $buildDir "install\include"
    if (Test-Path $includeDir) {
        $headerOut = Join-Path $OutArchDir "include"
        Ensure-Directory $headerOut
        Copy-Item "$includeDir\*" $headerOut -Recurse -Force
        Write-Host "  [COPY] include/ -> $headerOut"
    }
}

try {
    Check-File -Path $CmakeExe -Name "CMake"
    Check-Directory -Path $SrcDir -Name "OpenCV source"

    Build-Windows-Arch -Arch "x64" -OutArchDir $winX64Out
    Build-Windows-Arch -Arch "x86" -OutArchDir $winX86Out

    Write-Host "`n[SUCCESS] Windows builds completed."
} catch {
    Write-Error "Windows build failed: $($_.Exception.Message)"
    exit 1
}