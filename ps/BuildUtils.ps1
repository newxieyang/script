[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
# Build System Utility Functions

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

function Get-WslPath {
    param([string]$WinPath)
    if ($WinPath -match "^([a-zA-Z]):\\(.*)$") {
        $drive = $Matches[1].ToLower()
        $rest = $Matches[2] -replace '\\', '/'
        return "/mnt/$drive/$rest"
    }
    return $WinPath -replace '\\', '/'
}
