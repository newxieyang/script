[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
# Build System Utility Functions

# 公共路径配置（真源：config/paths.json）—— dot-source 本文件的脚本会自动拿到
# $cmake / $ninja / $msbuild / $ndkPath / $toolchain / $llvmStrip / $readelf /
# $androidPlatform / $vsGenerator / $ScriptRepoWsl 等变量，不要再各自写死路径。
. (Join-Path $PSScriptRoot "env_paths.ps1")

function Check-File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "${Name} 不存在: ${Path}"
    }
    Write-Host "[OK] ${Name}: ${Path}"
}

function Check-Directory {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "${Name} 不存在: ${Path}"
    }
    Write-Host "[OK] ${Name}: ${Path}"
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Remove-BuildDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Write-Host "Cleaning build directory: ${Path}"
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
    New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
}

function Invoke-CMakeConfigure {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][string]$CmakeExe
    )
    Write-Host "`n------------------------------------------------------------"
    Write-Host "CMake Configure: ${TargetName}"
    Write-Host "------------------------------------------------------------"
    & $CmakeExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "CMake configure failed: ${TargetName}, exit code=$LASTEXITCODE"
    }
}

function Invoke-CMakeBuild {
    param(
        [Parameter(Mandatory = $true)][string]$BuildDir,
        [Parameter(Mandatory = $true)][string]$TargetName,
        [switch]$VisualStudio,
        [Parameter(Mandatory = $true)][string]$CmakeExe,
        [int]$BuildJobs = 8
    )
    Write-Host "`n------------------------------------------------------------"
    Write-Host "CMake Build: ${TargetName}"
    Write-Host "------------------------------------------------------------"
    if ($VisualStudio) {
        & $CmakeExe --build $BuildDir --config Release --parallel $BuildJobs
    } else {
        & $CmakeExe --build $BuildDir --parallel $BuildJobs
    }
    if ($LASTEXITCODE -ne 0) {
        throw "CMake build failed: ${TargetName}, exit code=$LASTEXITCODE"
    }
}

function Find-Artifact {
    param(
        [Parameter(Mandatory = $true)][string]$BuildDir,
        [Parameter(Mandatory = $true)][string]$FileName,
        [string]$SearchDir,
        [switch]$Optional
    )
    if ([string]::IsNullOrWhiteSpace($SearchDir)) { $SearchDir = $BuildDir }
    if (-not (Test-Path -LiteralPath $SearchDir -PathType Container)) {
        if ($Optional) { return $null }
        throw "搜索目录不存在: ${SearchDir}"
    }
    $file = Get-ChildItem -LiteralPath $SearchDir -Recurse -File -Filter $FileName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $file) {
        if ($Optional) { return $null }
        throw "找不到产物: ${FileName} in ${SearchDir}"
    }
    return $file
}

function Copy-Artifact {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][string]$OutDir
    )
    Ensure-Directory $OutDir
    $destination = Join-Path $OutDir $File.Name
    Copy-Item -LiteralPath $File.FullName -Destination $destination -Force -ErrorAction Stop
    Write-Host "  [COPY] $($File.Name) -> ${OutDir}"
}

function Test-CMakePresetAvailable {
    <#
        .SYNOPSIS
            判断某个 configure preset 在当前机器上能不能直接用。
        .DESCRIPTION
            拿 `cmake --list-presets` 当探针：它不需要工具链就能跑通，能读通说明
            源目录的 CMakePresets.json（含 include 到仓库的 cmake-presets/sdk-presets.json
            的引用链）是有效的；而且 CMake 会按当前平台过滤掉生成器不可用的 preset
            （Linux 下列不出 VS2019 的那些），所以命中即代表"本机真的能用它构建"。
            任一环节不满足就返回 $false，调用方回退到手工参数数组。
            调用期间临时放宽 $ErrorActionPreference —— 本脚本的调用方普遍设了 Stop，
            探针失败属于预期情况，不该把整个构建打断。
        .OUTPUTS
            [bool]
    #>
    param(
        [Parameter(Mandatory = $true)][string]$CmakeExe,
        [Parameter(Mandatory = $true)][string]$SrcDir,
        [Parameter(Mandatory = $true)][string]$PresetName
    )
    if (-not (Test-Path -LiteralPath (Join-Path $SrcDir "CMakePresets.json") -PathType Leaf) -and
        -not (Test-Path -LiteralPath (Join-Path $SrcDir "CMakeUserPresets.json") -PathType Leaf)) {
        return $false
    }

    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $CmakeExe --list-presets -S $SrcDir 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { return $false }
        return $output -match ("`"" + [regex]::Escape($PresetName) + "`"")
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $previous
    }
}
