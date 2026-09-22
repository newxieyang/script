[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
# copyUtils.ps1
# encoding: utf-8
# 对应 py/utils/copyUtils.py，目录名与忽略规则保持一致

. "$PSScriptRoot\fileUtils.ps1"

# ------------------------------------------------------------
# 目录名约定（与 py 一致，不要随意加版本后缀）：
#   Windows exe/dll : win_X86Demo / win_X64Demo
#   Windows 源码    : simpleWin
#   Android 源码    : simpleAndroid
#   Qt Linux 源码   : simpleLinux
# ------------------------------------------------------------

function Copy-WinExe {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TgRoot
    )
    $srcX86 = Join-Path $SrcDir "Release"
    $dstX86 = Join-Path $TgRoot "win_X86Demo"
    Copy-FilesBySuffix -SrcRoot $srcX86 -DstDir $dstX86 -SuffixList @(".exe", ".dll")

    $srcX64 = Join-Path $SrcDir "x64\Release"
    $dstX64 = Join-Path $TgRoot "win_X64Demo"
    Copy-FilesBySuffix -SrcRoot $srcX64 -DstDir $dstX64 -SuffixList @(".exe", ".dll")
}

function Copy-AndroidApk {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetDir
    )
    $srcApkRoot = Join-Path $SrcDir "app\build\outputs\apk\debug"
    Copy-FilesBySuffix -SrcRoot $srcApkRoot -DstDir $TargetDir -SuffixList @(".apk")
}

function Copy-WinSourceCode {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    # py: ignore_win_code = ["Release", "x64", ".vs", ".git"]
    # 额外排除 IDE/构建中间目录，避免把 cmake-build-* 传进 SDK
    $ignore = @(
        "Release", "x64", ".vs", ".git", ".idea", "CMakeFiles",
        "cmake-build-release-vs2019_x86", "cmake-build-release-vs2019_x64"
    )
    $dstCode = Join-Path $TargetRoot "simpleWin"
    [void](Copy-DirectoryFiltered -SrcDir $SrcDir -DstDir $dstCode -ExcludeNames $ignore -Label "Windows源码")
}

function Copy-AndroidSourceCode {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    # py: ignore_android_code = [".gradle", ".git", ".idea", "build", ".cxx"]
    $ignore = @(".gradle", ".git", ".idea", "build", ".cxx")
    $dstCode = Join-Path $TargetRoot "simpleAndroid"
    [void](Copy-DirectoryFiltered -SrcDir $SrcDir -DstDir $dstCode -ExcludeNames $ignore -Label "Android源码")
}
