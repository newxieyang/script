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

function Get-VisibleChildItem {
    <#
        .SYNOPSIS
            深度优先遍历文件（不返回目录），遇到隐藏目录直接剪枝。
            等价于 py fileUtils.is_hidden + os.walk(dirs[:] = ...) 的行为，
            即：任意一层祖先目录以 . / $ / cmake / src 开头，则该目录下的文件全部忽略。
    #>
    param([Parameter(Mandatory)][string]$Path)
    foreach ($item in (Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)) {
        if ($item.PSIsContainer) {
            if (Test-IsHiddenName $item.Name) { continue }
            Get-VisibleChildItem -Path $item.FullName
        } else {
            $item
        }
    }
}

function Find-FilePathByKeyword {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$Key
    )
    if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) { return $null }

    # 用 Contains 而非 -like：关键字里的 . [ ] 等字符不应被当成通配符，且与 py 一样大小写敏感
    Get-VisibleChildItem -Path $ProjectDir |
        Where-Object { $_.Name.Contains($Key) } |
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

function Copy-DirectoryFiltered {
    <#
        .SYNOPSIS
            目录整体复制（robocopy），可排除指定名称的子目录。
            对应 py 的 shutil.copytree(..., ignore=...)，但用 robocopy 更稳。
        .OUTPUTS
            [bool] 是否真的执行了复制（源目录不存在时返回 $false）
    #>
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$DstDir,
        [string[]]$ExcludeNames = @(),
        [string]$Label = ""
    )
    if (-not (Test-Path -LiteralPath $SrcDir -PathType Container)) {
        Write-Host "[跳过] $Label 源目录不存在: $SrcDir"
        return $false
    }
    if (Test-Path -LiteralPath $DstDir) { Remove-DirectorySafe $DstDir }
    New-SafeDirectory $DstDir

    $robocopyArgs = @($SrcDir, $DstDir, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/nc", "/ns", "/np")
    if ($ExcludeNames.Count -gt 0) {
        $robocopyArgs += ($ExcludeNames | ForEach-Object { "/XD"; $_ })
    }
    & robocopy @robocopyArgs | Out-Null

    # robocopy: 0~7 为成功（位标志），>=8 才是失败
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy 复制失败 (exit=$LASTEXITCODE): $SrcDir -> $DstDir"
    }
    Write-Host "[复制$Label] $SrcDir -> $DstDir"
    return $true
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
