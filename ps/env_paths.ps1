<#
公共路径配置（唯一真源：仓库根 paths.json）
=====================================================================
任何脚本 dot-source 本文件即可直接使用下列变量，不要再往脚本里写死路径：

  Windows 侧工具   $cmake  $ninja  $msbuild  $python
  Android SDK/NDK  $sdkPath  $ndkPath
  由 $ndkPath 派生 $toolchain（android.toolchain.cmake）
                   $llvmStrip  $readelf（llvm-strip.exe / llvm-readelf.exe）
  WSL 容器侧       $wslGccX64  $wslGccAarch64（gcc-9.3 / aarch64 交叉编译器根）
                   $wslCmake  $wslNinja  $wslPython
  构建常量         $androidPlatform  $androidStl  $androidAbis
                   $vsGenerator  $vsArchX86  $vsArchX64
  仓库自身         $ScriptRepoWin  $ScriptRepoWsl
                   $WslBuildScript  $WslOpencvScript

路径转换函数：Get-WslPath <win路径>  /  Get-WinPathFromWsl <wsl路径>
（全仓库只此一份实现，别在别的脚本里再写一遍正则）

以 -Batch 调用时（bat/config.bat 用）不定义变量，改为向 stdout 打印
`set "name=value"` 行，供 cmd 的 for /f 直接执行。
#>
param([switch]$Batch)

function Get-WslPath {
    <# Windows 路径 -> WSL 路径：D:\a\b 或 D:/a/b  =>  /mnt/d/a/b #>
    param([string]$WinPath)
    if ([string]::IsNullOrWhiteSpace($WinPath)) { return $WinPath }
    if ($WinPath -match "^([a-zA-Z]):[\\/](.*)$") {
        $drive = $Matches[1].ToLower()
        $rest = $Matches[2] -replace '\\', '/'
        return "/mnt/$drive/$rest"
    }
    return $WinPath -replace '\\', '/'
}

function Get-WinPathFromWsl {
    <# WSL 路径 -> Windows 路径：/mnt/d/a/b  =>  D:\a\b #>
    param([string]$WslPath)
    if ([string]::IsNullOrWhiteSpace($WslPath)) { return $WslPath }
    if ($WslPath -match "^/mnt/([a-zA-Z])/(.*)$") {
        $drive = $Matches[1].ToUpper()
        $rest = $Matches[2] -replace '/', '\'
        return "${drive}:\$rest"
    }
    return $WslPath -replace '/', '\'
}

# ---------------------------------------------------------------
# 读取唯一真源
# ---------------------------------------------------------------
$PathsFile = Join-Path (Split-Path $PSScriptRoot -Parent) "paths.json"
if (-not (Test-Path -LiteralPath $PathsFile -PathType Leaf)) {
    throw "找不到公共路径配置: $PathsFile"
}
$PathsCfg = Get-Content -LiteralPath $PathsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$WinCfg = $PathsCfg.windows
$WslCfg = $PathsCfg.wsl

# Windows 侧工具
$cmake = $WinCfg.cmake
$ninja = $WinCfg.ninja
$msbuild = $WinCfg.msbuild
$python = $WinCfg.python
$sdkPath = $WinCfg.android_sdk
$ndkPath = $WinCfg.android_ndk

# 由 NDK 根派生：换 NDK 版本只改 paths.json 的 android_ndk，这里自动跟随
$toolchain = "$ndkPath/build/cmake/android.toolchain.cmake"
$llvmBin = "$ndkPath/toolchains/llvm/prebuilt/windows-x86_64/bin"
$llvmStrip = "$llvmBin/llvm-strip.exe"
$readelf = "$llvmBin/llvm-readelf.exe"

# WSL 容器侧工具
$wslCmake = $WslCfg.cmake
$wslNinja = $WslCfg.ninja
$wslPython = $WslCfg.python
$wslGccX64 = $WslCfg.gcc_x64_root
$wslGccAarch64 = $WslCfg.gcc_aarch64_root

# 构建常量
$androidPlatform = $PathsCfg.android.platform
$androidStl = $PathsCfg.android.stl
$androidAbis = @($PathsCfg.android.abis -split ',')
$vsGenerator = $PathsCfg.vs.generator
$vsArchX86 = $PathsCfg.vs.arch_x86
$vsArchX64 = $PathsCfg.vs.arch_x64

# 仓库自身位置（Windows / WSL 两种形式）
$ScriptRepoWin = Split-Path $PSScriptRoot -Parent
$ScriptRepoWsl = Get-WslPath $ScriptRepoWin
$WslBuildScript = "$ScriptRepoWsl/shell/buildOXiAll.sh"
$WslOpencvScript = "$ScriptRepoWsl/shell/opencv-wsl.sh"

# bat 侧要的 Android 参数串（与 preset 里的 android-common 同义）
$androidParam = "-DCMAKE_BUILD_TYPE=Release" +
    " -DANDROID_STL=$androidStl" +
    " -DANDROID_PLATFORM=$androidPlatform" +
    " -DCMAKE_TOOLCHAIN_FILE=$toolchain" +
    " -DCMAKE_MAKE_PROGRAM=$ninja" +
    " -G Ninja"

# ---------------------------------------------------------------
# -Batch：给 cmd 用，打印 set 行后结束（dot-source 时 $Batch 为 $false，不受影响）
# ---------------------------------------------------------------
if ($Batch) {
    $batchVars = [ordered]@{
        cmake = $cmake
        ninja = $ninja
        toolchain = $toolchain
        msbuild = $msbuild
        python = $python
        strip = $llvmStrip
        readelf = $readelf
        sdkPath = $sdkPath
        ndkPath = $ndkPath
        androidPlatform = $androidPlatform
        androidParam = $androidParam
    }
    foreach ($key in $batchVars.Keys) {
        Write-Output ('set "{0}={1}"' -f $key, $batchVars[$key])
    }
}
