<#
.SYNOPSIS
    OXiScan SDK One-Click Build and Package Script
    Targets: Linux (x64/arm), Windows (x86/x64), Android (v7/v8)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# 1. Path Configuration
# ============================================================
$SdkRoot = "D:\git\oxi\shenzhen\oxiscansdk"
$BuildRoot = "D:\git\oxi\shenzhen\build"
$VersionFile = Join-Path $SdkRoot "version.cmake"

# $WslBuildScript = "/mnt/d/wsl/buildOXiAll.sh"
$WslBuildScript = "/mnt/d/git/script/shell/buildOXiAll.sh"
$WinAndroidScript = "D:\git\script\ps\BuildWinAndroid.ps1"
$PackageScript = "D:\git\script\ps\OXi.ps1"
# $PythonScript = "D:\git\script\py\OXi.py"

# Demo Directories
$DemoAndroid = "D:\git\oxi\shenzhen\oxiscansdk_Android\libFAP\src\main\cpp"
$DemoQt = "D:\git\oxi\shenzhen\oxiscansdk_qt"
$DemoWin = "D:\git\oxi\shenzhen\oxiscansdk_win"

# ============================================================
# 2. Parse Version
# ============================================================
if (-not (Test-Path $VersionFile)) {
    throw "Version file not found: $VersionFile"
}

$versionContent = Get-Content $VersionFile -Raw
$major = ([regex]::Match($versionContent, 'set\(FAP_VERSION_MAJOR\s+(\d+)\)')).Groups[1].Value
$minor = ([regex]::Match($versionContent, 'set\(FAP_VERSION_MINOR\s+(\d+)\)')).Groups[1].Value
$patch = ([regex]::Match($versionContent, 'set\(FAP_VERSION_PATCH\s+(\d+)\)')).Groups[1].Value
$build = ([regex]::Match($versionContent, 'set\(FAP_VERSION_BUILD\s+(\d+)\)')).Groups[1].Value

if (-not ($major -and $minor -and $patch -and $build)) {
    throw "Failed to parse version from version.cmake"
}

$version = "$major.$minor.$patch.$build"
$outRoot = Join-Path $BuildRoot "OXiScanV$version"


Write-Host "`n============================================================"
Write-Host " OXiScan SDK Build - Version: $version"
Write-Host " Output Directory: $outRoot"
Write-Host "============================================================`n"

$startTime = Get-Date

# ============================================================
# 3. Build Linux (WSL)
# ============================================================
Write-Host "[1/5] Building Linux via WSL (x64 and ARM64)..."
wsl bash $WslBuildScript --linux-only

# ============================================================
# 4. Build Windows and Android
# ============================================================
Write-Host "`n[2/5] Building Windows and Android libraries..."
if (-not (Test-Path $WinAndroidScript)) {
    throw "Windows build script not found: $WinAndroidScript"
}

& $WinAndroidScript -OutRootWsl $outRoot

# ============================================================
# 5. Sync Libraries to Demo Folders
# ============================================================
Write-Host "`n[3/5] Syncing artifacts to Demo directories..."

function Copy-Library {
    param($Src, $Dst)
    if (Test-Path $Src) {
        if (-not (Test-Path $Dst)) { New-Item -ItemType Directory -Path $Dst -Force | Out-Null }
        Copy-Item -Path $Src -Destination $Dst -Force
        Write-Host "  [COPY] $(Split-Path $Src -Leaf) -> $Dst"
    } else {
        Write-Warning "  [SKIP] File not found: $Src"
    }
}

# Android
Copy-Library "$outRoot\Android\arm64-v8a\libFAP.a" "$DemoAndroid\arm64-v8a\"
Copy-Library "$outRoot\Android\arm64-v8a\libFAP.so" "$DemoAndroid\arm64-v8a\"
Copy-Library "$outRoot\Android\armeabi-v7a\libFAP.a" "$DemoAndroid\armeabi-v7a\"
Copy-Library "$outRoot\Android\armeabi-v7a\libFAP.so" "$DemoAndroid\armeabi-v7a\"

# Linux (Qt)
Copy-Library "$outRoot\Linux\arm\libFAP.a" "$DemoQt\arm\"
Copy-Library "$outRoot\Linux\arm\libFAP.so" "$DemoQt\arm\"
Copy-Library "$outRoot\Linux\x64\libFAP.a" "$DemoQt\x64\"
Copy-Library "$outRoot\Linux\x64\libFAP.so" "$DemoQt\x64\"

# Windows
Copy-Library "$outRoot\Windows\x64\static\FAP.lib" "$DemoWin\static\libx64\"
Copy-Library "$outRoot\Windows\x64\shared\FAP.lib" "$DemoWin\shared\libx64\"
Copy-Library "$outRoot\Windows\x64\shared\FAP.dll" "$DemoWin\shared\libx64\"
Copy-Library "$outRoot\Windows\x64\shared\FAP.dll" "$DemoWin\x64\Release"

Copy-Library "$outRoot\Windows\x86\static\FAP.lib" "$DemoWin\static\libx86\"
Copy-Library "$outRoot\Windows\x86\shared\FAP.lib" "$DemoWin\shared\libx86\"
Copy-Library "$outRoot\Windows\x86\shared\FAP.dll" "$DemoWin\shared\libx86\"
Copy-Library "$outRoot\Windows\x86\shared\FAP.dll" "$DemoWin\Release\"

# ============================================================
# 6. Run Python SDK Packager
# ============================================================
# Write-Host "`n[4/5] Running Python SDK packager..."
# if (-not (Test-Path $PythonScript)) {
#     throw "Python packager script not found: $PythonScript"
# }

# $pythonDir = Split-Path $PythonScript -Parent
# Push-Location $pythonDir
# try {
#     python OXi.py
# } finally {
#     Pop-Location
# }
# ============================================================
# 6. Run Python SDK Packager
# ============================================================
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& $PackageScript -SdkKey GSER



# ============================================================
# 7. Complete
# ============================================================
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`n============================================================"
Write-Host " ALL TASKS COMPLETED SUCCESSFULLY"
Write-Host " Version: $version"
Write-Host " Duration: $($duration.TotalSeconds.ToString('F1')) seconds"
Write-Host "============================================================`n"
