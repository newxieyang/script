[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
# fileUtils.ps1
# encoding: utf-8

function Test-IsHiddenName {
    param([string]$Name)
    if ($Name.StartsWith('.')) { return $true }
    if ($Name.StartsWith('$')) { return $true }
    if ($Name.StartsWith('cmake')) { return $true }
    if ($Name.StartsWith('src')) { return $true }
    return $false
}

function Find-FilePathByKeyword {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$Key
    )
    if (-not (Test-Path $ProjectDir)) { return $null }

    Get-ChildItem -Path $ProjectDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsHiddenName $_.Directory.Name) -and
            ($_.Name -like "*$Key*")
        } |
        Select-Object -First 1 -ExpandProperty FullName
}

function Get-CmakeVersions {
    param([Parameter(Mandatory)][string]$ProjectDir)

    $filePath = Join-Path $ProjectDir "version.cmake"
    if (-not (Test-Path $filePath)) {
        throw "version.cmake not found: $filePath"
    }

    $content = Get-Content -Path $filePath -Raw -Encoding UTF8

    function Get-CmakeVar([string]$VarName, [string]$Text) {
        $pattern = "set\s*\(\s*$VarName\s+([^)\s]+)\s*\)"
        $m = [regex]::Match($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { return $m.Groups[1].Value }
        return $null
    }

    $algVer    = Get-CmakeVar "OXiAlgVer" $content
    $fapMajor  = Get-CmakeVar "FAP_VERSION_MAJOR" $content
    $fapMinor  = Get-CmakeVar "FAP_VERSION_MINOR" $content
    $fapPatch  = Get-CmakeVar "FAP_VERSION_PATCH" $content
    $fapBuild  = Get-CmakeVar "FAP_VERSION_BUILD" $content
    $buildStatic = $false

    $fapFull = "$fapMajor.$fapMinor.$fapPatch.$fapBuild"

    $isEven = $false
    try {
        $buildNum = [int]$fapBuild
        $isEven = ($buildNum % 2 -eq 0)
    } catch {
        $isEven = $false
    }

    $final = $fapFull
    if ($isEven -and $algVer) {
        $final = "$fapFull (Alg: $algVer)"
    }

    [PSCustomObject]@{
        algorithm_version = $algVer
        fap_version       = $fapFull
        is_include_alg    = $isEven
        build_static      = $buildStatic
        final_string      = $final
    }
}

function New-SafeDirectory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "[创建目录] $Path"
    }
}

function Remove-DirectorySafe {
    param([Parameter(Mandatory)][string]$DirPath)
    if (-not (Test-Path -LiteralPath $DirPath)) { return }
    try {
        Remove-Item -LiteralPath $DirPath -Recurse -Force
        Write-Host "[删除目录] $DirPath"
    } catch {
        Write-Warning "[删除警告] $DirPath : $_"
    }
}

function Copy-FilesBySuffix {
    param(
        [Parameter(Mandatory)][string]$SrcRoot,
        [Parameter(Mandatory)][string]$DstDir,
        [Parameter(Mandatory)][string[]]$SuffixList
    )
    if (-not (Test-Path -LiteralPath $SrcRoot -PathType Container)) {
        Write-Host "[跳过] 源目录不存在: $SrcRoot"
        return
    }
    New-SafeDirectory $DstDir

    Get-ChildItem -Path $SrcRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $name = $_.Name
            $SuffixList | Where-Object { $name.EndsWith($_) }
        } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $DstDir -Force
            Write-Host "  复制: $($_.Name)"
        }
}
