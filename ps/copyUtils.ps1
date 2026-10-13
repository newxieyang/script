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

# ------------------------------------------------------------
# 打包忽略目录（ps / py 两侧必须一致：py/utils/copyUtils.py 的 PACK_IGNORE_DIRS）
#   统一在这里定义，别在各处复制粘贴 —— 新增一类要忽略的目录只需改这一处。
#   注意：
#     * .workbuddy / .git / .idea / .vs 都是编辑器或工具目录，任何一份 SDK 都不该带
#     * cmake-build* 只能用通配：真实目录名是 cmake-build-release-vs2019_x64 之类，
#       写精确名（cmake-build-release）根本匹配不上
#     * "cmake"（无横线）不在列表里 —— A910_qt\cmake 下是 toolchain-*.cmake 源码
# ------------------------------------------------------------
function Get-PackIgnoreDirs {
    <#
        .SYNOPSIS
            按用途取"打包时要排除的子目录名"列表。
        .PARAMETER Kind
            win     : simpleWin（Windows 源码树）
            android : simpleAndroid（Android 源码树）
            qt      : simpleLinux（Qt 源码树）
            doc     : doc（文档目录）
        .OUTPUTS
            [string[]] 目录名列表；bare 名（如 .workbuddy）匹配任意层级，带 * 的按通配匹配
    #>
    param([Parameter(Mandatory)][ValidateSet("win", "android", "qt", "doc")][string]$Kind)
    switch ($Kind) {
        "win" { @("Release", "x64", ".vs", ".vscode", ".git", ".idea", ".workbuddy", "CMakeFiles", "cmake-build*") }
        "android" { @(".gradle", ".git", ".idea", ".workbuddy", ".cxx", "build", "cmake-build*") }
        "qt" { @(".git", ".idea", ".vs", ".vscode", ".workbuddy", "build", ".cxx", "CMakeFiles", "cmake-build*") }
        "doc" { @(".git", ".workbuddy") }
    }
}

# ------------------------------------------------------------
# Windows 产物目录解析
#   同一套 demo 代码有两种工程形态，exe/dll 落点不同：
#     VS 工程   : <SdkDir>\Release                    / <SdkDir>\x64\Release
#     CMake 工程: <SdkDir>\cmake-build-release-vs2019_x86\Release
#                 <SdkDir>\cmake-build-release-vs2019_x64\Release
#   （A910_win、oxiscansdk_win_mut 这类只有 CMake 产物）
# ------------------------------------------------------------
function Get-WinDemoCandidateDirs {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][ValidateSet("x86", "x64")][string]$Arch
    )
    $vsSub    = if ($Arch -eq "x64") { "x64\Release" } else { "Release" }
    $cmakeSub = if ($Arch -eq "x64") { "cmake-build-release-vs2019_x64\Release" } else { "cmake-build-release-vs2019_x86\Release" }
    @(
        (Join-Path $SrcDir $vsSub),
        (Join-Path $SrcDir $cmakeSub)
    )
}

function Resolve-WinDemoDir {
    <#
        .SYNOPSIS
            按优先级挑出该架构下真正含有 .exe 的输出目录：
            先看 VS 的 Release / x64\Release，里面没有 .exe（或目录不存在）时，
            回退到 CMake 的 cmake-build-release-vs2019_<arch>\Release。
        .OUTPUTS
            [string] 命中的目录；候选目录都没有 .exe 时返回 $null
    #>
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][ValidateSet("x86", "x64")][string]$Arch
    )
    foreach ($dir in (Get-WinDemoCandidateDirs -SrcDir $SrcDir -Arch $Arch)) {
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        $exe = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter "*.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($exe) { return $dir }
    }
    return $null
}

function Copy-WinExe {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TgRoot
    )
    foreach ($arch in @("x86", "x64")) {
        $dst = Join-Path $TgRoot $(if ($arch -eq "x64") { "win_X64Demo" } else { "win_X86Demo" })
        $src = Resolve-WinDemoDir -SrcDir $SrcDir -Arch $arch

        if (-not $src) {
            $tried = (Get-WinDemoCandidateDirs -SrcDir $SrcDir -Arch $arch) -join "  |  "
            Write-Host "[跳过] $arch 未找到含 .exe 的输出目录，已尝试: $tried"
            continue
        }
        Write-Host "[$arch 产物目录] $src"
        Copy-FilesBySuffix -SrcRoot $src -DstDir $dst -SuffixList @(".exe", ".dll")
    }
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
    # py: ignore_win_code（PACK_IGNORE_DIRS["win"]）
    # 排除 IDE/构建中间目录 + .workbuddy/.git 之类的工程元数据（用 Get-PackIgnoreDirs，别写死）
    $ignore = @(Get-PackIgnoreDirs -Kind win)
    $dstCode = Join-Path $TargetRoot "simpleWin"
    [void](Copy-DirectoryFiltered -SrcDir $SrcDir -DstDir $dstCode -ExcludeNames $ignore -Label "Windows源码")
}

function Copy-AndroidSourceCode {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    # py: ignore_android_code（PACK_IGNORE_DIRS["android"]）
    $ignore = @(Get-PackIgnoreDirs -Kind android)
    $dstCode = Join-Path $TargetRoot "simpleAndroid"
    [void](Copy-DirectoryFiltered -SrcDir $SrcDir -DstDir $dstCode -ExcludeNames $ignore -Label "Android源码")
}
