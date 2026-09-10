# OXi.ps1
# encoding: utf-8
# 用法: .\OXi.ps1
# 可选: .\OXi.ps1 -SdkKey GSER -OnlyApp
param (
    [string]$SdkKey = "GSER",
    [switch]$OnlyApp
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\fileUtils.ps1"
. "$PSScriptRoot\copyUtils.ps1"

function Copy-Headers {
    param (
        [Parameter(Mandatory)][string[]]$SrcFiles,
        [Parameter(Mandatory)][string]$TargetDir
    )
    New-SafeDirectory $TargetDir
    foreach ($src in $SrcFiles) {
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Host "[跳过] 文件不存在: $src"
            continue
        }
        Copy-Item -LiteralPath $src -Destination $TargetDir -Force
        Write-Host "[复制头文件] $src"
    }
}

function Copy-HeadersByKeyword {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetDir,
        [Parameter(Mandatory)][string[]]$Keywords
    )
    if (Test-Path $TargetDir) { Remove-DirectorySafe $TargetDir }
    New-SafeDirectory $TargetDir

    foreach ($key in $Keywords) {
        $fp = Find-FilePathByKeyword -ProjectDir $SrcDir -Key $key
        if ($fp) {
            Copy-Item -LiteralPath $fp -Destination $TargetDir -Force
            Write-Host "[复制头文件] $fp"
        } else {
            Write-Host "[未找到] $key"
        }
    }
}

function Copy-WinLib {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$LibName,
        [Parameter(Mandatory)][string]$TargetDir,
        [string[]]$Headers = $null
    )
    New-SafeDirectory $TargetDir
    if ($Headers) { Copy-Headers -SrcFiles $Headers -TargetDir $TargetDir }

    $x86Src = Join-Path $SrcDir "cmake-build-release-vs2019_x86\libFAP\Release"
    $libX86 = Join-Path $TargetDir "libx86"
    $dllX86 = Join-Path $TargetDir "Release"
    New-SafeDirectory $libX86
    New-SafeDirectory $dllX86
    Copy-Item (Join-Path $x86Src "$LibName.lib") $libX86 -Force
    Copy-Item (Join-Path $x86Src "$LibName.dll") $dllX86 -Force

    $x64Src = Join-Path $SrcDir "cmake-build-release-vs2019_x64\libFAP\Release"
    $libX64 = Join-Path $TargetDir "libx64"
    $dllX64 = Join-Path $TargetDir "x64\Release"
    New-SafeDirectory $libX64
    New-SafeDirectory $dllX64
    Copy-Item (Join-Path $x64Src "$LibName.lib") $libX64 -Force
    Copy-Item (Join-Path $x64Src "$LibName.dll") $dllX64 -Force
}

function Copy-AndroidLib {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$LibName,
        [Parameter(Mandatory)][string]$TargetDir,
        [string[]]$Headers = $null
    )
    $includeDir = Join-Path $TargetDir "include"
    New-SafeDirectory $includeDir
    if ($Headers) { Copy-Headers -SrcFiles $Headers -TargetDir $includeDir }

    $v7 = Join-Path $TargetDir "armeabi-v7a"
    $v8 = Join-Path $TargetDir "arm64-v8a"
    New-SafeDirectory $v7
    New-SafeDirectory $v8

    $soName = "lib$LibName.so"
    Copy-Item (Join-Path $SrcDir "cmake-build-release-armeabi-v7a\libFAP\$soName") $v7 -Force
    Copy-Item (Join-Path $SrcDir "cmake-build-release-arm64-v8a\libFAP\$soName") $v8 -Force
}

function Copy-QtSimpleLinux {
    param(
        [Parameter(Mandatory)][string]$QtDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    if (-not (Test-Path $QtDir)) {
        Write-Host "[跳过] oxiscansdk_qt 不存在: $QtDir"
        return
    }
    $dst = Join-Path $TargetRoot "simpleLinux"
    if (Test-Path $dst) { Remove-DirectorySafe $dst }
    Copy-Item -LiteralPath $QtDir -Destination $dst -Recurse -Force
    Write-Host "[复制Qt Linux] $QtDir -> $dst"
}

function Copy-Doc {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot,
        [switch]$KeepLatest
    )
    $dst = Join-Path $TargetRoot "doc"
    if (Test-Path $dst) { Remove-DirectorySafe $dst }
    Copy-Item -LiteralPath $SrcDir -Destination $dst -Recurse -Force
    Write-Host "[复制文档] $SrcDir -> $dst"

    if ($KeepLatest) {
        $docs = @(Get-ChildItem -Path $dst -Filter "*.docx" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime)
        if ($docs.Count -gt 1) {
            $docs[0..($docs.Count - 2)] | ForEach-Object {
                Remove-Item $_.FullName -Force
                Write-Host "[删除旧文档] $($_.FullName)"
            }
        }
    }
}

function New-SdkPackage {
    param(
        [Parameter(Mandatory)][string]$SdkName,
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][string]$WinDir,
        [Parameter(Mandatory)][string]$AndroidDir,
        [Parameter(Mandatory)][string]$QtDir,
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][hashtable]$Config,
        [bool]$OnlyApp = $false
    )

    $result  = Get-CmakeVersions -ProjectDir $SdkDir
    $version = $result.fap_version
    Write-Host "`n====== $SdkName SDK $version ======"

    $suffix = ""
    if ($OnlyApp) {
        $target = Join-Path $TargetRoot ($Config.prefix + $version + "App")
    } else {
        $target = Join-Path $TargetRoot ($Config.prefix + $version + $suffix)
    }

    if (Test-Path $target) { Remove-DirectorySafe $target }
    New-SafeDirectory $target

    if (-not $OnlyApp) {
        if ($Config.ContainsKey('header_keyword') -and $Config.header_keyword -and $Config.header_keyword.Count -gt 0) {
            Copy-HeadersByKeyword -SrcDir $SdkDir `
                -TargetDir (Join-Path $target "include") `
                -Keywords $Config.header_keyword
        }
        elseif ($Config.ContainsKey('headers') -and $Config.headers -and $Config.headers.Count -gt 0) {
            Copy-Headers -SrcFiles $Config.headers `
                -TargetDir (Join-Path $target "include")
        }

        if ($Config.copy_win_lib) {
            Copy-WinLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target
        }
        Copy-WinSourceCode -SrcDir $WinDir -TargetRoot $target
    }
    Copy-WinExe -SrcDir $WinDir -TgRoot $target

    if (-not $OnlyApp) {
        if ($Config.copy_android_lib) {
            Copy-AndroidLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target
        }
        Copy-AndroidSourceCode -SrcDir $AndroidDir -TargetRoot $target
    }
    Copy-AndroidApk -SrcDir $AndroidDir -TargetDir $target

    if (-not $OnlyApp) {
        Copy-QtSimpleLinux -QtDir $QtDir -TargetRoot $target

        if ($Config.doc) {
            $keep = [bool]$Config.keep_latest_doc
            Copy-Doc -SrcDir $Config.doc -TargetRoot $target -KeepLatest:$keep
        }
        Write-Host "`n完成: $target"
    }

    return $target
}

function Import-SdkConfig {
    param([string]$Path = $null)
    if (-not $Path) {
        $Path = Join-Path $PSScriptRoot "sdk_config.json"
    }
    if (-not (Test-Path $Path)) {
        throw "配置文件不存在: $Path"
    }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    return $raw
}

# ===================== 入口 =====================

 Write-Host "start package"
function Convert-ToSdkHashtable {
    param($Node)
    $h = @{}
    foreach ($p in $Node.PSObject.Properties) {
        $name = $p.Name
        $val  = $p.Value
        if ($null -eq $val) {
            $h[$name] = $null
        }
        elseif ($val -is [System.Array] -or $val -is [System.Collections.IList]) {
            $h[$name] = @($val)
        }
        else {
            $h[$name] = $val
        }
    }
    return $h
}

$cfgRoot = Get-Content (Join-Path $PSScriptRoot "sdk_config.json") -Raw -Encoding UTF8 |
    ConvertFrom-Json

$sdkNode = $cfgRoot.$SdkKey
if (-not $sdkNode) { throw "sdk_config.json 中找不到键: $SdkKey" }

$sdk = Convert-ToSdkHashtable $sdkNode

# header_keyword 统一成 string[]
if ($sdk.ContainsKey('header_keyword') -and $sdk.header_keyword) {
    $sdk.header_keyword = @($sdk.header_keyword)
}
if ($sdk.headers) {
    $sdk.headers = @($sdk.headers)
}

# JSON 里 false 进来是 Boolean
$sdk.copy_win_lib     = [bool]$sdk.copy_win_lib
$sdk.copy_android_lib = [bool]$sdk.copy_android_lib
$sdk.keep_latest_doc  = [bool]$sdk.keep_latest_doc

$winDir     = $sdk.sdk_dir.TrimEnd('\', '/') + "_win"
$androidDir = $sdk.sdk_dir.TrimEnd('\', '/') + "_Android"
$qtDir      = $sdk.sdk_dir.TrimEnd('\', '/') + "_qt"

$target = New-SdkPackage `
    -SdkName    $sdk.name `
    -SdkDir     $sdk.sdk_dir `
    -WinDir     $winDir `
    -AndroidDir $androidDir `
    -QtDir      $qtDir `
    -TargetRoot $sdk.target_root `
    -Config     $sdk `
    -OnlyApp    ([bool]$OnlyApp)

Write-Host "输出目录: $target"