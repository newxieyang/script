param (
    [string]$SdkKey = "GSER",
    [string]$ConfigFile = "",
    [switch]$OnlyApp,
    [string]$Suffix = ""
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# OXi.ps1 — SDK 打包脚本（对应 py/OXi.py，行为保持一致）
#
# 用法:
#   .\OXi.ps1                                   # 打包 GSER
#   .\OXi.ps1 -SdkKey MIAXIS                   # 指定机型
#   .\OXi.ps1 -SdkKey MIAXIS -OnlyApp          # 只出 App 包
#   .\OXi.ps1 -SdkKey A910 -Suffix Static      # 包目录追加后缀
#
# 输出包结构（与 py 一致）:
#   include/            头文件（header_keyword 搜索 或 headers 指定）
#   win_X86Demo/        x86 exe+dll
#   win_X64Demo/        x64 exe+dll
#   simpleWin/          Windows 源码
#   simpleAndroid/      Android 源码
#   *.apk               Android 调试包
#   simpleLinux/        Qt Linux 源码
#   doc/                文档
# ============================================================

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\fileUtils.ps1"
. "$PSScriptRoot\copyUtils.ps1"

# ============================================================
# 通用工具
# ============================================================
function Copy-FileSafe {
    param(
        [Parameter(Mandatory)][string]$SrcFile,
        [Parameter(Mandatory)][string]$DstDir
    )
    if (-not (Test-Path -LiteralPath $SrcFile -PathType Leaf)) {
        Write-Warning "[跳过] 文件不存在: $SrcFile"
        return $false
    }
    New-SafeDirectory $DstDir
    Copy-Item -LiteralPath $SrcFile -Destination $DstDir -Force
    Write-Host "  [复制] $(Split-Path $SrcFile -Leaf) -> $DstDir"
    return $true
}

function Copy-Headers {
    param (
        [AllowEmptyString()][AllowEmptyCollection()][Parameter(Mandatory)][string[]]$SrcFiles,
        [Parameter(Mandatory)][string]$TargetDir
    )
    # 容错：配置里可能有空字符串 / null 条目（py 端只会打印 [跳过]）
    $files = @($SrcFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($files.Count -eq 0) {
        Write-Host "[跳过] 头文件列表为空"
        return
    }
    New-SafeDirectory $TargetDir
    foreach ($src in $files) {
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
        [AllowEmptyString()][AllowEmptyCollection()][Parameter(Mandatory)][string[]]$Keywords
    )
    $keys = @($Keywords | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($keys.Count -eq 0) {
        Write-Host "[跳过] 关键字列表为空"
        return
    }
    if (Test-Path $TargetDir) { Remove-DirectorySafe $TargetDir }
    New-SafeDirectory $TargetDir

    foreach ($key in $keys) {
        $fp = Find-FilePathByKeyword -ProjectDir $SrcDir -Key $key
        if ($fp) {
            Copy-Item -LiteralPath $fp -Destination $TargetDir -Force
            Write-Host "[复制头文件] $fp"
        } else {
            Write-Host "[未找到] $key"
        }
    }
}

# ============================================================
# 库复制（对应 py 的 copy_win_lib / copy_android_lib）
# ============================================================
function Copy-WinLib {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$LibName,
        [Parameter(Mandatory)][string]$TargetDir,
        [string[]]$Headers
    )
    New-SafeDirectory $TargetDir
    if ($Headers) { Copy-Headers -SrcFiles $Headers -TargetDir $TargetDir }

    # x86: lib -> libx86, dll -> Release
    $x86Src = Join-Path $SrcDir "cmake-build-release-vs2019_x86\libFAP\Release"
    Copy-FileSafe -SrcFile (Join-Path $x86Src "$LibName.lib") -DstDir (Join-Path $TargetDir "libx86")
    Copy-FileSafe -SrcFile (Join-Path $x86Src "$LibName.dll") -DstDir (Join-Path $TargetDir "Release")

    # x64: lib -> libx64, dll -> x64\Release
    $x64Src = Join-Path $SrcDir "cmake-build-release-vs2019_x64\libFAP\Release"
    Copy-FileSafe -SrcFile (Join-Path $x64Src "$LibName.lib") -DstDir (Join-Path $TargetDir "libx64")
    Copy-FileSafe -SrcFile (Join-Path $x64Src "$LibName.dll") -DstDir (Join-Path $TargetDir "x64\Release")
}

function Copy-AndroidLib {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$LibName,
        [Parameter(Mandatory)][string]$TargetDir,
        [string[]]$Headers
    )
    $includeDir = Join-Path $TargetDir "include"
    New-SafeDirectory $includeDir
    if ($Headers) { Copy-Headers -SrcFiles $Headers -TargetDir $includeDir }

    $soName = "lib$LibName.so"
    Copy-FileSafe -SrcFile (Join-Path $SrcDir "cmake-build-release-armeabi-v7a\libFAP\$soName") -DstDir (Join-Path $TargetDir "armeabi-v7a")
    Copy-FileSafe -SrcFile (Join-Path $SrcDir "cmake-build-release-arm64-v8a\libFAP\$soName") -DstDir (Join-Path $TargetDir "arm64-v8a")
}

# ============================================================
# 源码 / 文档复制
# ============================================================
function Copy-QtSimpleLinux {
    param(
        [Parameter(Mandatory)][string]$QtDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    # py 直接 copytree；这里排除 IDE/构建目录，避免把 .git、build 传进 SDK
    $ignore = @(".git", ".idea", "build", ".cxx", "CMakeFiles", "cmake-build-release", "cmake-build-debug")
    $dst = Join-Path $TargetRoot "simpleLinux"
    [void](Copy-DirectoryFiltered -SrcDir $QtDir -DstDir $dst -ExcludeNames $ignore -Label "Qt Linux源码")
}

function Copy-Doc {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot,
        [switch]$KeepLatest
    )
    if (-not (Test-Path -LiteralPath $SrcDir -PathType Container)) {
        Write-Host "[跳过] 文档目录不存在: $SrcDir"
        return
    }

    $dst = Join-Path $TargetRoot "doc"
    if (Test-Path $dst) { Remove-DirectorySafe $dst }
    New-SafeDirectory $dst
    Get-ChildItem -LiteralPath $SrcDir -Force | Copy-Item -Destination $dst -Recurse -Force
    Write-Host "[复制文档] $SrcDir -> $dst"

    if ($KeepLatest) {
        $docs = @(Get-ChildItem -Path $dst -Filter "*.docx" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime)
        if ($docs.Count -gt 1) {
            $docs[0..($docs.Count - 2)] | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force
                Write-Host "[删除旧文档] $($_.FullName)"
            }
        }
    }
}

# ============================================================
# 打包主流程（对应 py 的 create_package）
# ============================================================
function New-SdkPackage {
    param(
        [Parameter(Mandatory)][string]$SdkName,
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][string]$WinDir,
        [Parameter(Mandatory)][string]$AndroidDir,
        [Parameter(Mandatory)][string]$QtDir,
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][hashtable]$Config,
        [bool]$OnlyApp = $false,
        [string]$Suffix = ""
    )

    $result  = Get-CmakeVersions -ProjectDir $SdkDir
    $version = $result.fap_version
    Write-Host "`n====== $SdkName SDK $version ======"

    if ($OnlyApp) {
        $target = Join-Path $TargetRoot ($Config.prefix + $version + "App")
    } else {
        $target = Join-Path $TargetRoot ($Config.prefix + $version + $Suffix)
    }

    if (Test-Path $target) { Remove-DirectorySafe $target }
    New-SafeDirectory $target

    # -------------------------
    # headers
    # -------------------------
    if (-not $OnlyApp) {
        $keywords = if ($Config.ContainsKey('header_keyword')) { @($Config.header_keyword) } else { @() }
        $headerFiles = if ($Config.ContainsKey('headers')) { @($Config.headers) } else { @() }

        if ($keywords.Count -gt 0) {
            Copy-HeadersByKeyword -SrcDir $SdkDir -TargetDir (Join-Path $target "include") -Keywords $keywords
        } elseif ($headerFiles.Count -gt 0) {
            Copy-Headers -SrcFiles $headerFiles -TargetDir (Join-Path $target "include")
        } else {
            Write-Warning "[跳过] 未配置 header_keyword / headers，include 目录为空"
        }
    }

    # -------------------------
    # windows
    # -------------------------
    if (-not $OnlyApp) {
        if ($Config.copy_win_lib) {
            Copy-WinLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target
        }
        Copy-WinSourceCode -SrcDir $WinDir -TargetRoot $target
    }
    Copy-WinExe -SrcDir $WinDir -TgRoot $target

    # -------------------------
    # android
    # -------------------------
    if (-not $OnlyApp) {
        if ($Config.copy_android_lib) {
            Copy-AndroidLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target
        }
        Copy-AndroidSourceCode -SrcDir $AndroidDir -TargetRoot $target
    }
    Copy-AndroidApk -SrcDir $AndroidDir -TargetDir $target

    # -------------------------
    # Qt simpleLinux
    # -------------------------
    if (-not $OnlyApp) {
        Copy-QtSimpleLinux -QtDir $QtDir -TargetRoot $target
    }

    # -------------------------
    # doc
    # -------------------------
    if (-not $OnlyApp) {
        if ($Config.doc) {
            $keep = [bool]$Config.keep_latest_doc
            Copy-Doc -SrcDir $Config.doc -TargetRoot $target -KeepLatest:$keep
        } else {
            Write-Host "[跳过] 未配置 doc"
        }
    }

    return $target
}

# ============================================================
# 配置加载
# ============================================================
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

# ============================================================
# 入口
# ============================================================
if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $ConfigFile = Join-Path $PSScriptRoot "sdk_config.json"
}
if (-not (Test-Path -LiteralPath $ConfigFile)) {
    throw "配置文件不存在: $ConfigFile"
}

$cfgRoot = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
$sdkNode = $cfgRoot.$SdkKey
if (-not $sdkNode) {
    $keys = ($cfgRoot.PSObject.Properties.Name -join ", ")
    throw "sdk_config.json 中找不到键: $SdkKey（可用: $keys）"
}

$sdk = Convert-ToSdkHashtable $sdkNode

# 必填字段校验（对应 py 里会直接 KeyError 的位置）
foreach ($field in @('name', 'sdk_dir', 'target_root', 'prefix', 'lib')) {
    if (-not $sdk.ContainsKey($field) -or [string]::IsNullOrWhiteSpace([string]$sdk[$field])) {
        throw "sdk_config.json[$SdkKey] 缺少必填字段: $field"
    }
}

# header_keyword / headers 统一为 string[]，并剔除空条目
$sdk['header_keyword'] = if ($sdk.ContainsKey('header_keyword') -and $sdk.header_keyword) {
    @($sdk.header_keyword | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
} else { @() }
$sdk['headers'] = if ($sdk.ContainsKey('headers') -and $sdk.headers) {
    @($sdk.headers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
} else { @() }

# 布尔值安全转换
foreach ($flag in @('copy_win_lib', 'copy_android_lib', 'keep_latest_doc')) {
    $sdk[$flag] = if ($sdk.ContainsKey($flag) -and $null -ne $sdk[$flag]) { [bool]$sdk[$flag] } else { $false }
}

$sdkDir     = ([string]$sdk.sdk_dir).TrimEnd('\', '/')
$winDir     = $sdkDir + "_win"
$androidDir = $sdkDir + "_Android"
$qtDir      = $sdkDir + "_qt"

Write-Host "====== 打包 $SdkKey ======"
Write-Host "  源码目录 : $sdkDir"
Write-Host "  输出根目录: $($sdk.target_root)"

$target = New-SdkPackage `
    -SdkName    $sdk.name `
    -SdkDir     $sdkDir `
    -WinDir     $winDir `
    -AndroidDir $androidDir `
    -QtDir      $qtDir `
    -TargetRoot $sdk.target_root `
    -Config     $sdk `
    -OnlyApp    ([bool]$OnlyApp) `
    -Suffix     $Suffix

# ============================================================
# 结果清单
# ============================================================
Write-Host "`n[完成] $target"
Write-Host "包内容:"
Get-ChildItem -LiteralPath $target | Sort-Object Name | ForEach-Object {
    if ($_.PSIsContainer) { Write-Host "  [DIR ] $($_.Name)" }
    else { Write-Host "  [FILE] $($_.Name)" }
}
Write-Host "输出目录: $target"
