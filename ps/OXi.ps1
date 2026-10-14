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
#   simpleLinux/        Qt Linux 源码（含 linux/ 下的预编译库，原样拷贝，不重新构建）
#                        打包时排除 .git / .workbuddy / cmake-build* / build / .idea
#                        等非源码目录（规则见 copyUtils.ps1 的 Get-PackIgnoreDirs）
#   doc/                文档（打包时同样排除 .workbuddy / .git）
#
# 拷贝开关（config/sdk_config.json，为 false 表示该平台整块不进包）:
#   copy_win_lib     ：Win 库(Copy-WinLib) + simpleWin 源码 + win_X86Demo/win_X64Demo 测试案例
#   copy_android_lib ：Android 库 + simpleAndroid 源码 + *.apk 测试案例
#   copy_linux_lib   ：simpleLinux（Qt 源码 + linux/ 下的预编译库，只拷不构建）
#   should_package   ：是否由 buildOXiAll.ps1 自动调用本脚本出包（手动直接调用本脚本时仅提示、不阻断）
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
    # x64: lib -> libx64, dll -> x64\Release
    $x64Src = Join-Path $SrcDir "cmake-build-release-vs2019_x64\libFAP\Release"
    if (-not (Test-Path -LiteralPath $x86Src) -and -not (Test-Path -LiteralPath $x64Src)) {
        # 本机各机型都属这种形态（库由构建流程产出，不在这两个 cmake-build 目录里），
        # 给一行提示即可，不必逐个文件刷 4 条 [跳过]
        Write-Host "[跳过] Win 库源目录不存在: $SrcDir\cmake-build-release-vs2019_{x86,x64}\libFAP\Release"
        return
    }

    # ⚠️ 必须用 [void](...) 吃掉返回值：Copy-FileSafe 会 return $true/$false，
    # 不被吞掉就会漏进 New-SdkPackage 的输出流，使 $target 变成
    # "True True True True True True <路径>" 这样的数组，末尾的包内容清单随之报错。
    [void](Copy-FileSafe -SrcFile (Join-Path $x86Src "$LibName.lib") -DstDir (Join-Path $TargetDir "libx86"))
    [void](Copy-FileSafe -SrcFile (Join-Path $x86Src "$LibName.dll") -DstDir (Join-Path $TargetDir "Release"))

    [void](Copy-FileSafe -SrcFile (Join-Path $x64Src "$LibName.lib") -DstDir (Join-Path $TargetDir "libx64"))
    [void](Copy-FileSafe -SrcFile (Join-Path $x64Src "$LibName.dll") -DstDir (Join-Path $TargetDir "x64\Release"))
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
    $srcV7 = Join-Path $SrcDir "cmake-build-release-armeabi-v7a\libFAP"
    $srcV8 = Join-Path $SrcDir "cmake-build-release-arm64-v8a\libFAP"
    if (-not (Test-Path -LiteralPath (Join-Path $srcV7 $soName)) -and -not (Test-Path -LiteralPath (Join-Path $srcV8 $soName))) {
        Write-Host "[跳过] Android 库源目录不存在: $SrcDir\cmake-build-release-{arm64-v8a,armeabi-v7a}\libFAP\$soName"
        return
    }

    # 同上：吃掉 Copy-FileSafe 的布尔返回值，别让它污染 $target
    [void](Copy-FileSafe -SrcFile (Join-Path $srcV7 $soName) -DstDir (Join-Path $TargetDir "armeabi-v7a"))
    [void](Copy-FileSafe -SrcFile (Join-Path $srcV8 $soName) -DstDir (Join-Path $TargetDir "arm64-v8a"))
}

# ============================================================
# 源码 / 文档复制
# ============================================================
function Find-QtLinuxLibDir {
    <#
        .SYNOPSIS
            在 Qt 工程目录下找预编译库目录：<QtDir>\linux（大小写不敏感，实际多为 Linux）。
        .OUTPUTS
            [System.IO.DirectoryInfo] 命中的目录；没有则 $null
    #>
    param([Parameter(Mandatory)][string]$QtDir)
    if (-not (Test-Path -LiteralPath $QtDir -PathType Container)) { return $null }
    Get-ChildItem -LiteralPath $QtDir -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq "linux" } |
        Select-Object -First 1
}

function Copy-QtLinuxLibs {
    <#
        .SYNOPSIS
            把 <QtDir>\linux 下的预编译库整份拷进 simpleLinux\<原名>。**只拷贝，不做任何构建。**
            该目录是源码树之外的预编译产物（按架构分子目录，如 aarch64/x64/arm）；
            由于 WSL 下建的 .so 多为符号链接，robocopy 容易拷成 0 字节，
            这里按文件逐个拷：Copy-Item 会跟随链接取到真实内容，并保留子目录结构。
        .OUTPUTS
            [bool] 是否真的复制到了文件
    #>
    param(
        [Parameter(Mandatory)][string]$QtDir,
        [Parameter(Mandatory)][string]$DstDir
    )
    $libDir = Find-QtLinuxLibDir -QtDir $QtDir
    if (-not $libDir) {
        Write-Host "[跳过] $QtDir 下没有 linux 库目录"
        return $false
    }
    $dstLib = Join-Path $DstDir $libDir.Name
    if (Test-Path -LiteralPath $dstLib) { Remove-DirectorySafe $dstLib }
    New-SafeDirectory $dstLib

    $copied = 0
    $failed = 0
    # 按文件逐个拷的同时也把 .workbuddy 之类的工程元数据目录剪掉（该目录理论上只有库文件，做个兜底）
    $files = @(Get-ChildItem -LiteralPath $libDir.FullName -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer -and $_.FullName -notmatch '[\\/]\.workbuddy[\\/]' })

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($libDir.FullName.Length).TrimStart('\', '/')
        $dstFile = Join-Path $dstLib $rel
        New-SafeDirectory (Split-Path $dstFile -Parent)
        try {
            Copy-Item -LiteralPath $f.FullName -Destination $dstFile -Force -ErrorAction Stop
            $copied++
        } catch {
            $failed++
            Write-Warning "[Qt Linux库] 复制失败: $rel ($($_.Exception.Message))"
        }
    }

    $archs = @(Get-ChildItem -LiteralPath $dstLib -Directory -Force -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.Name)($(@(Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }).Count))" })
    $summary = "复制 $copied 个文件"
    if ($failed -gt 0) { $summary += "，失败 $failed 个" }
    if ($archs.Count -gt 0) { $summary += "（" + ($archs -join ', ') + "）" }
    Write-Host "[Qt Linux库] $($libDir.Name): $summary"

    return ($copied -gt 0)
}

function Copy-QtSimpleLinux {
    param(
        [Parameter(Mandatory)][string]$QtDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    # 排除非源码目录，避免把 .git（几十~上百 MB）、.workbuddy、cmake-build*（IDE/构建产物）打进 SDK。
    # 规则集中在 copyUtils.ps1 的 Get-PackIgnoreDirs（"qt"），与 py 的 PACK_IGNORE_DIRS["qt"] 一一对应：
    #   * cmake-build* 必须写成通配：实际目录名是 cmake-build-release-vs2019_x64 / cmake-build-debug 等，
    #     写精确名（cmake-build-release）根本匹配不上，会整份拷进 simpleLinux。
    #   * "cmake"（无横线）不能排除 —— A910_qt\cmake 里是 toolchain-*.cmake 源码。
    $ignore = @(Get-PackIgnoreDirs -Kind qt)
    $dst = Join-Path $TargetRoot "simpleLinux"

    # 库目录单独处理，避免被源码树那趟拷贝漏掉/拷成空文件
    $libDir = Find-QtLinuxLibDir -QtDir $QtDir
    if ($libDir) { $ignore += $libDir.Name }

    [void](Copy-DirectoryFiltered -SrcDir $QtDir -DstDir $dst -ExcludeNames $ignore -Label "Qt Linux源码")
    [void](Copy-QtLinuxLibs -QtDir $QtDir -DstDir $dst)
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
    # 文档目录同样排除 .workbuddy/.git 之类的工程元数据（Get-PackIgnoreDirs "doc"）；
    # 该函数自带"先删目标目录再建"，等价于原实现
    [void](Copy-DirectoryFiltered -SrcDir $SrcDir -DstDir $dst `
            -ExcludeNames (Get-PackIgnoreDirs -Kind doc) -Label "文档")

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
    # windows  （copy_win_lib 控制：库 + simpleWin 源码 + demo 测试案例）
    # -------------------------
    if ($Config.copy_win_lib) {
        if (-not $OnlyApp) {
            Copy-WinLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target
            Copy-WinSourceCode -SrcDir $WinDir -TargetRoot $target
        }
        Copy-WinExe -SrcDir $WinDir -TgRoot $target
    } else {
        Write-Host "[跳过] copy_win_lib=false：不拷贝 Win demo（库 / simpleWin 源码 / win_X86Demo、win_X64Demo 测试案例）"
    }

    # -------------------------
    # android  （copy_android_lib 控制：库 + simpleAndroid 源码 + apk 测试案例）
    # -------------------------
    if ($Config.copy_android_lib) {
        if (-not $OnlyApp) {
            Copy-AndroidLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target
            Copy-AndroidSourceCode -SrcDir $AndroidDir -TargetRoot $target
        }
        Copy-AndroidApk -SrcDir $AndroidDir -TargetDir $target
    } else {
        Write-Host "[跳过] copy_android_lib=false：不拷贝 Android demo（库 / simpleAndroid 源码 / *.apk 测试案例）"
    }

    # -------------------------
    # Qt simpleLinux  （copy_linux_lib 控制：Qt 源码 + linux/ 预编译库，只拷不构建）
    # -------------------------
    if ($Config.copy_linux_lib) {
        if (-not $OnlyApp) {
            Copy-QtSimpleLinux -QtDir $QtDir -TargetRoot $target
        }
    } else {
        Write-Host "[跳过] copy_linux_lib=false：不拷贝 simpleLinux（Qt 源码 + linux/ 下的预编译库）"
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
    $ConfigFile = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "config") "sdk_config.json"
}
if (-not (Test-Path -LiteralPath $ConfigFile)) {
    throw "配置文件不存在: $ConfigFile"
}

$cfgRoot = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
$sdkNode = $cfgRoot.$SdkKey
if (-not $sdkNode) {
    $keys = ($cfgRoot.PSObject.Properties.Name -join ", ")
    throw "config/sdk_config.json 中找不到键: $SdkKey（可用: $keys）"
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

# 布尔值安全转换（缺字段按 false 处理，避免 StrictMode/绑定异常）
foreach ($flag in @('copy_win_lib', 'copy_android_lib', 'copy_linux_lib', 'keep_latest_doc', 'should_package')) {
    $sdk[$flag] = if ($sdk.ContainsKey($flag) -and $null -ne $sdk[$flag]) { [bool]$sdk[$flag] } else { $false }
}

$sdkDir     = ([string]$sdk.sdk_dir).TrimEnd('\', '/')
$winDir     = $sdkDir + "_win"
$androidDir = $sdkDir + "_Android"
$qtDir      = $sdkDir + "_qt"

Write-Host "====== 打包 $SdkKey ======"
Write-Host "  源码目录 : $sdkDir"
Write-Host "  输出根目录: $($sdk.target_root)"
Write-Host ("  拷贝开关 : copy_win_lib={0}  copy_android_lib={1}  copy_linux_lib={2}  should_package={3}" -f `
        $sdk.copy_win_lib.ToString().ToLower(), `
        $sdk.copy_android_lib.ToString().ToLower(), `
        $sdk.copy_linux_lib.ToString().ToLower(), `
        $sdk.should_package.ToString().ToLower())
if (-not $sdk.should_package) {
    Write-Host "  [提示] should_package=false：buildOXiAll.ps1 不会自动调用打包；当前是手动直接调用，继续出包。"
}

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
