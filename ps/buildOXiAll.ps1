param (
    [string]$SdkKey = "GSER",
    [string]$ConfigFile = "D:\git\script\ps\sdk_config.json"
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
<#
.SYNOPSIS
    OXiScan SDK One-Click Build and Package Script
    Targets: Linux (x64/arm), Windows (x86/x64), Android (v7/v8)
#>



# 解决中文乱码问题

. (Join-Path $PSScriptRoot "BuildUtils.ps1")
# 复用与 py 一致的复制工具（Copy-WinExe / Copy-WinSourceCode / Copy-AndroidApk / Copy-AndroidSourceCode）
. (Join-Path $PSScriptRoot "copyUtils.ps1")
. (Join-Path $PSScriptRoot "fileUtils.ps1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# 1. Load Configuration
# ============================================================
if (-not (Test-Path $ConfigFile)) {
    throw "Configuration file not found: $ConfigFile"
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
if (-not $config.PSObject.Properties[$SdkKey]) {
    throw "SDK Key '$SdkKey' not found in config file."
}

$sdkConfig = $config.$SdkKey

# ============================================================
# 2. Path Configuration from Config
# ============================================================
$SdkRoot = $sdkConfig.sdk_dir -replace '/', '\'
$LibBaseName = $sdkConfig.lib

# build_static may be absent in some configs; guard against StrictMode
$BuildStatic = $false
if ($sdkConfig.PSObject.Properties["build_static"]) {
    $BuildStatic = [bool]$sdkConfig.build_static
}
$BuildStaticStr = if ($BuildStatic) { "true" } else { "false" }

# should_package may be absent in some configs; default to false
$ShouldPackage = $false
if ($sdkConfig.PSObject.Properties["should_package"]) {
    $ShouldPackage = [bool]$sdkConfig.should_package
}

# Derived Paths
$BuildRoot = Join-Path (Split-Path $SdkRoot -Parent) "build"
$VersionFile = Join-Path $SdkRoot "version.cmake"

# Find 3rd directory by traversing up from SdkRoot
$ThirdPartyDir = ""
$currentDir = $SdkRoot
while (-not [string]::IsNullOrEmpty($currentDir)) {
    $potential3rd = Join-Path $currentDir "3rd"
    if (Test-Path $potential3rd -PathType Container) {
        $ThirdPartyDir = $potential3rd
        break
    }
    $parent = Split-Path $currentDir -Parent
    if ($parent -eq $currentDir) { break }
    $currentDir = $parent
}

if ([string]::IsNullOrEmpty($ThirdPartyDir)) {
    # Default fallback to the known location if discovery fails
    $ThirdPartyDir = "D:\git\3rd"
    Write-Warning "Could not dynamically find '3rd' directory. Falling back to: $ThirdPartyDir"
}

$WslBuildScript = "/mnt/d/git/script/shell/buildOXiAll.sh"
$BuildWinScript = Join-Path $PSScriptRoot "BuildWin.ps1"
$BuildAndroidScript = Join-Path $PSScriptRoot "BuildAndroid.ps1"
$PackageScript = Join-Path $PSScriptRoot "OXi.ps1"

# Demo Directories
$AndroidProjectRoot = $SdkRoot + "_Android"
$DemoAndroid = Join-Path $AndroidProjectRoot "lib$LibBaseName\src\main\cpp"
$DemoQt = $SdkRoot + "_qt"
$DemoWin = $SdkRoot + "_win"

# ============================================================
# 3. Parse Version
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
$outRoot = Join-Path $BuildRoot "$($sdkConfig.prefix)$version"


Write-Host "`n============================================================"
Write-Host " OXiScan SDK Build - Key: $SdkKey, Version: $version"
Write-Host " SdkRoot: $SdkRoot"
Write-Host " Output Directory: $outRoot"
Write-Host " Build Static: $BuildStaticStr"
Write-Host "============================================================`n"

$startTime = Get-Date

$wslSdkRoot = Get-WslPath $SdkRoot
$wslOutRoot = Get-WslPath $outRoot
$wslThirdPartyDir = Get-WslPath $ThirdPartyDir

# ============================================================
# 4. Build Linux (WSL)
# ============================================================
if ($sdkConfig.build_linux) {
    Write-Host "[1/5] Building Linux via WSL (x64 and ARM64)..."

    # 只传构建所需的路径；demo 目录不在这里预建（各 SDK 的 qt/demo 目录约定不统一，
    # 预建会往源码树里塞空目录），改由下面的同步/打包步骤按需创建。
    wsl bash $WslBuildScript `
        --src-dir "$wslSdkRoot" `
        --build-root "$wslOutRoot" `
        --third-party "$wslThirdPartyDir" `
        --lib-name "$LibBaseName" `
        --build-static "$BuildStaticStr" `
        --linux-only
} else {
    Write-Host "[1/5] Skipping Linux build."
}

# ============================================================
# 5. Build Windows
# ============================================================
if ($sdkConfig.build_windows) {
    Write-Host "`n[2/5] Building Windows libraries..."
    & $BuildWinScript `
        -OutRootWsl $wslOutRoot `
        -SdkRoot $SdkRoot `
        -ThirdPartyDir $ThirdPartyDir `
        -LibBaseName $LibBaseName `
        -BuildStatic ([bool]$sdkConfig.build_static)
} else {
    Write-Host "`n[2/5] Skipping Windows build."
}

# ============================================================
# 6. Build Android
# ============================================================
if ($sdkConfig.build_android) {
    Write-Host "`n[3/5] Building Android libraries..."
    & $BuildAndroidScript `
        -OutRootWsl $wslOutRoot `
        -SdkRoot $SdkRoot `
        -ThirdPartyDir $ThirdPartyDir `
        -LibBaseName $LibBaseName `
        -BuildStatic ([bool]$sdkConfig.build_static) `
        -AndroidProjectRoot $AndroidProjectRoot
} else {
    Write-Host "`n[3/5] Skipping Android build."
}

# ============================================================
# 7. Sync Libraries to Demo Folders
# ============================================================
Write-Host "`n[4/5] Syncing artifacts to Demo directories..."

function Copy-Library {
    param($Src, $Dst)
    if (Test-Path $Src) {
        if (-not (Test-Path $Dst)) { New-Item -ItemType Directory -Path $Dst -Force | Out-Null }
        Copy-Item -Path $Src -Destination $Dst -Force
        Write-Host "  [COPY] $(Split-Path $Src -Leaf) -> $Dst"
    }
}

# Copy-WinExe / Copy-WinSourceCode / Copy-AndroidApk / Copy-AndroidSourceCode
# 统一由 copyUtils.ps1 提供（脚本开头已 dot-source），避免两处命名漂移

$AndroidLibA = "lib$LibBaseName.a"
$AndroidLibSo = "lib$LibBaseName.so"
$WinLib = "$LibBaseName.lib"
$WinDll = "$LibBaseName.dll"

# Android Sync
if ($sdkConfig.build_android) {
    if ($BuildStatic) {
        Copy-Library "$outRoot\Android\arm64-v8a\$AndroidLibA" "$DemoAndroid\arm64-v8a\"
        Copy-Library "$outRoot\Android\armeabi-v7a\$AndroidLibA" "$DemoAndroid\armeabi-v7a\"
    }
    Copy-Library "$outRoot\Android\arm64-v8a\$AndroidLibSo" "$DemoAndroid\arm64-v8a\"
    Copy-Library "$outRoot\Android\armeabi-v7a\$AndroidLibSo" "$DemoAndroid\armeabi-v7a\"
}

# Linux Sync
if ($sdkConfig.build_linux) {
    if ($BuildStatic) {
        Copy-Library "$outRoot\Linux\aarch64\$AndroidLibA" "$DemoQt\Linux\aarch64\"
        Copy-Library "$outRoot\Linux\x64\$AndroidLibA" "$DemoQt\Linux\x64\"
    }
    Copy-Library "$outRoot\Linux\aarch64\$AndroidLibSo" "$DemoQt\Linux\aarch64\"
    Copy-Library "$outRoot\Linux\x64\$AndroidLibSo" "$DemoQt\Linux\x64\"
}

# Windows Sync
if ($sdkConfig.build_windows) {
    if ($BuildStatic) {
      Copy-Library "$outRoot\Windows\x64\static\$WinLib" "$DemoWin\static\libx64\"
      Copy-Library "$outRoot\Windows\x86\static\$WinLib" "$DemoWin\static\libx86\"
    }

    Copy-Library "$outRoot\Windows\x64\shared\$WinLib" "$DemoWin\shared\libx64\"
    Copy-Library "$outRoot\Windows\x64\shared\$WinDll" "$DemoWin\shared\libx64\"

    Copy-Library "$outRoot\Windows\x86\shared\$WinLib" "$DemoWin\shared\libx86\"
    Copy-Library "$outRoot\Windows\x86\shared\$WinDll" "$DemoWin\shared\libx86\"

}

# ============================================================
# 7.5. Copy Demo Source Code & Artifacts to Output
# ============================================================
Write-Host "`n[4.5/5] Copying demo source code and artifacts..."

if ($sdkConfig.build_windows) {
    Copy-WinExe -SrcDir $DemoWin -TgRoot $outRoot
    Copy-WinSourceCode -SrcDir $DemoWin -TargetRoot $outRoot
}

if ($sdkConfig.build_android) {
    Copy-AndroidApk -SrcDir $AndroidProjectRoot -TargetDir $outRoot
    Copy-AndroidSourceCode -SrcDir $AndroidProjectRoot -TargetRoot $outRoot
}

# ============================================================
# 8. Run SDK Packager
# ============================================================
if ($ShouldPackage) {
    Write-Host "`n[5/5] Running SDK packager..."
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    & $PackageScript -SdkKey $SdkKey
} else {
    Write-Host "`n[5/5] Skipping SDK packager (should_package = false)."
}

# ============================================================
# 9. Complete
# ============================================================
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "`n============================================================"
Write-Host " ALL TASKS COMPLETED SUCCESSFULLY"
Write-Host " Version: $version"
Write-Host " Duration: $($duration.TotalSeconds.ToString('F1')) seconds"
Write-Host "============================================================`n"
