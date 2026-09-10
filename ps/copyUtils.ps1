# copyUtils.ps1
# encoding: utf-8

. "$PSScriptRoot\fileUtils.ps1"

function Copy-WinExe {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TgRoot
    )
    $srcX86 = Join-Path $SrcDir "Release"
    $dstX86 = Join-Path $TgRoot "winx86DemoWithLib"
    Copy-FilesBySuffix -SrcRoot $srcX86 -DstDir $dstX86 -SuffixList @(".exe", ".dll")

    $srcX64 = Join-Path $SrcDir "x64\Release"
    $dstX64 = Join-Path $TgRoot "winx64DemoWithLib"
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
    $dstCode = Join-Path $TargetRoot "simpleWin"
    if (Test-Path $dstCode) { Remove-DirectorySafe $dstCode }

    $ignore = @("Release", "x64", ".vs", ".git")
    # 用 robocopy 排除目录更省事
    New-SafeDirectory $dstCode
    $xd = ($ignore | ForEach-Object { "/XD"; $_ })
    & robocopy $SrcDir $dstCode /E /NFL /NDL /NJH /NJS /nc /ns /np @xd | Out-Null
    Write-Host "[复制Windows源码] $SrcDir -> $dstCode"
}

function Copy-AndroidSourceCode {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    $dstCode = Join-Path $TargetRoot "simpleAndroid"
    if (Test-Path $dstCode) { Remove-DirectorySafe $dstCode }

    $ignore = @(".gradle", ".git", ".idea", "build", ".cxx")
    New-SafeDirectory $dstCode
    $xd = ($ignore | ForEach-Object { "/XD"; $_ })
    & robocopy $SrcDir $dstCode /E /NFL /NDL /NJH /NJS /nc /ns /np @xd | Out-Null
    Write-Host "[复制Android源码] $SrcDir -> $dstCode"
}