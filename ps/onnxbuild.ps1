<#
ONNX-Runtime Android + Windows 一键编译
Android:
    arm64-v8a
    armeabi-v7a

Windows:
    x64
    x86
#>

. env_paths.ps1


$root = "E:/3rdSRC/onnxruntime1.25.1"
$depCache = Join-Path $root "shared_deps"
$apiLevel = 28


$buildScript = Join-Path $root "tools\ci_build\build.py"


# =========================
# 公共CMake参数
# =========================

$cmakeDefines  = @(
    "ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=OFF",
    "CMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=4096",
    "CMAKE_EXE_LINKER_FLAGS=-Wl,-z,max-page-size=4096"
    "FETCHCONTENT_BASE_DIR=$depCache"
)



function Run-Build(
    [string]$Platform,
    [string]$Arch,
    [string]$OutDir
)
{

    if(Test-Path $OutDir)
    {
        Remove-Item -Recurse -Force $OutDir

        Write-Host ""
        Write-Host "[清理] $OutDir" -ForegroundColor Yellow
    }


    Write-Host ""
    Write-Host "====================================="
    Write-Host "开始编译:"
    Write-Host "平台: $Platform"
    Write-Host "架构: $Arch"
    Write-Host "输出: $OutDir"
    Write-Host "====================================="



    if($Platform -eq "Android")
    {

        python $buildScript `
            --android `
            --android_sdk_path $sdkPath `
            --android_ndk_path $ndkPath `
            --android_abi $Arch `
            --android_api $apiLevel `
            --build_shared_lib `
            --config Release `
            --build_dir $OutDir `
            --parallel 14 `
            --skip_tests `
            --cmake_generator Ninja `
            --cmake_extra_defines $cmakeDefines

    }
    elseif($Platform -eq "Windows")
    {

        if($Arch -eq "x64")
        {
            $vsArch="x64"
        }
        else
        {
            $vsArch="Win32"
        }


        python $buildScript `
            --build_shared_lib `
            --config Release `
            --build_dir $OutDir `
            --parallel 14 `
            --skip_tests `
            --cmake_generator "Visual Studio 16 2019" `
            --cmake_generator_toolset "host=x64" `
            --cmake_generator_platform $vsArch `
            --cmake_extra_defines $cmakeDefines
    }



    if($LASTEXITCODE -ne 0)
    {
        Write-Host ""
        Write-Host "? 编译失败" -ForegroundColor Red
        Write-Host "平台:$Platform 架构:$Arch"
        Write-Host "退出码:$LASTEXITCODE"

        exit $LASTEXITCODE
    }


    Write-Host ""
    Write-Host "? 编译成功 $Platform $Arch" -ForegroundColor Green
}



function Check-SoAlignment($soPath)
{
    if(-not(Test-Path $soPath))
    {
        Write-Host "未找到:$soPath" -ForegroundColor Yellow
        return
    }


    Write-Host ""
    Write-Host "[检查SO] $soPath"

    $header=& $readelf -l $soPath

    $header | Select-String "Align"
}



# =========================
# Android
# =========================

# $androidArm64="$root/build/Android_arm64_Release"

# Run-Build `
#     "Android" `
#     "arm64-v8a" `
#     $androidArm64



# =========================
# Windows
# =========================

# $win64="$root/build/Windows_x64_Release"

# Run-Build `
#     "Windows" `
#     "x64" `
#     $win64



$win32="$root/build/Windows_x86_Release"

Run-Build `
    "Windows" `
    "x86" `
    $win32



# =========================
# 检查Android SO
# =========================

Check-SoAlignment `
    "$androidArm64/Release/libonnxruntime.so"



Write-Host ""
Write-Host "=============================="
Write-Host "全部编译完成"
Write-Host "=============================="