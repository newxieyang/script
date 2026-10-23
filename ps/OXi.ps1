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
# Copy-FileSafe 已移到 ps/copyUtils.ps1（buildOXiAll.ps1 也要用，而它不加载本脚本）

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
    <#
        .SYNOPSIS
            Win 库复制：主库（.lib/.dll）+ 算法库 FAPAlgo + opencv / onnxruntime 运行时。
        .DESCRIPTION
            产物布局三种形态都认（cmake-build-<arch>\Release / libFAP\Release / build_temp\win\win_<arch>_*）。
            FAPAlgo 与主库必须同目录：OXiAlgoLoader 的搜索顺序是 config.ini 绝对路径 → cacheDir →
            FAP 自身目录 → 系统路径，分包放会让客户机加载失败。
    #>
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$LibName,
        [Parameter(Mandatory)][string]$TargetDir,
        [string[]]$Headers
    )
    New-SafeDirectory $TargetDir
    if ($Headers) { Copy-Headers -SrcFiles $Headers -TargetDir $TargetDir }

    foreach ($arch in @("x86", "x64")) {
        # 构建入口不同 → 产物落点不同（cmake-build-* / build_temp\win\win_<arch>_*），逐个探测
        $hit = Find-LibSource -SdkDir $SrcDir -Kind win -Arch $arch `
            -SubDirs @("Release", "libFAP\Release") -MustContain "$LibName.dll"
        if (-not $hit) {
            $tried = (Get-LibBuildDirs -SdkDir $SrcDir -Kind win -Arch $arch) -join "  |  "
            Write-Host "[跳过] $arch 库源目录不存在（已尝试 Release 与 libFAP\Release）: $tried"
            continue
        }
        $src = $hit.SrcDir

        # 参考包结构（A910 G6SDK）：.lib 进 simpleWin\libx86|libx64，
        # 整组 dll 进 simpleWin\shared\libx86|libx64，包根不放任何库
        $winRoot = Join-Path $TargetDir "simpleWin"
        $libDst = Join-Path $winRoot $(if ($arch -eq "x64") { "libx64" } else { "libx86" })
        $binDst = Join-Path $winRoot $(if ($arch -eq "x64") { "shared\libx64" } else { "shared\libx86" })

        # ⚠️ 必须用 [void](...) 吃掉返回值：Copy-FileSafe 会 return $true/$false，
        # 不被吞掉就会漏进 New-SdkPackage 的输出流，使 $target 变成
        # "True True True True True True <路径>" 这样的数组，末尾的包内容清单随之报错。
        [void](Copy-FileSafe -SrcFile (Join-Path $src "$LibName.lib") -DstDir $libDst)

        # 主库 + FAPAlgo + opencv/onnxruntime 一起拷（$LibName.dll 也在里面）
        $n = Copy-LibFiles -SrcDir $src -DstDir $binDst -Kind dll
        Write-Host "  [$arch 库] $LibName.lib -> $libDst"
        Write-Host "  [$arch 运行时] $n 个 dll -> $binDst"

        # 旧构建 / 没开算法的构建里没有 *Algo*.dll —— 这种包客户机上跑不起来，必须吼一声
        if (-not (Get-ChildItem -LiteralPath $src -File -Filter "*Algo*.dll" -ErrorAction SilentlyContinue)) {
            Write-Host "[警告] $arch 构建目录里没有算法库（*Algo*.dll），包内 demo 可能加载失败: $src"
        }
    }
}

function Copy-WinStaticLibs {
    <#
        .SYNOPSIS
            刷新包内 simpleWin\static\lib<arch>（静态链接那套 .lib + 运行时 dll）。
        .DESCRIPTION
            _win demo 把静态库 checked-in 在 static\lib<arch> 下（CMakeLists 的 GSER_LIB_DIR =
            <static|shared>/lib<arch>），源码树那趟拷贝只是原样搬旧文件；Copy-WinLib 只写
            lib<arch> 与 shared\lib<arch>，于是走 -DBUILD_STATIC_LIBS=ON 的客户拿到的永远是
            几个月前那份 FAP.lib（缺新修的导出与行为修复）。

            这里按 ON 构建产物覆盖：`$LibName.lib` 一定刷；同目录里**已存在**的 dll 同名覆盖。
            不新增 dll 文件 —— 该目录的 dll 没人 glob，加进去只会平白撑大包体。
    #>
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][string]$LibName
    )
    foreach ($arch in @("x86", "x64")) {
        $dst = Join-Path (Join-Path $TargetRoot "simpleWin\static") "lib$arch"
        if (-not (Test-Path -LiteralPath $dst -PathType Container)) {
            Write-Host "[跳过] 包内没有 simpleWin\static\lib$arch，跳过 Win 静态库刷新"
            continue
        }
        $hit = Find-StaticLibSource -SdkDir $SdkDir -Kind win -Arch $arch `
            -FileName "$LibName.lib" -SubDirs @("Release", "libFAP\Release")
        if (-not $hit) {
            Write-Host "[警告] $arch 没找到静态构建目录（win_${arch}_ON），包内 simpleWin\static\lib$arch 仍是旧库"
            continue
        }
        $src = $hit.SrcDir
        [void](Copy-FileSafe -SrcFile (Join-Path $src "$LibName.lib") -DstDir $dst)

        $dllCount = 0
        foreach ($f in @(Get-ChildItem -LiteralPath $src -File -Filter "*.dll" -ErrorAction SilentlyContinue)) {
            if (-not (Test-Path -LiteralPath (Join-Path $dst $f.Name) -PathType Leaf)) { continue }
            Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
            $dllCount++
        }
        Write-Host "  [$arch 静态库] $LibName.lib + $dllCount 个同名 dll -> $dst"
    }
}

function Copy-QtWinLibs {
    <#
        .SYNOPSIS
            刷新包内 simpleLinux\{shared,static}\Win\<X64|X86> —— Linux 样例在 Windows 上编译时用的厂商库。
        .DESCRIPTION
            *_qt 工程把这两套 Win 库 checked-in（见 oxiscansdk_qt/CMakeLists.txt：
            GSER_LIB_DIR = ${BUILD_STATIC_LIBS?static:shared}/Win|Linux/${ARCH}）：
              shared\Win\<arch>  动态版 FAP.lib + FAP.dll   ← 客户在 Windows 上按动态方式编 Linux 样例
              static\Win\<arch>  静态版 FAP.lib（无 dll）   ← 按静态方式编
            源码树那趟拷贝原样搬旧文件 → 这里按对应构建产物覆盖，否则 Windows 上编出来的样例
            会带着几个月前的库（其中 shared\Win\X86 还缺 FAP.dll，动态模式根本跑不起来）。
    #>
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][string]$LibName
    )
    $qtRoot = Join-Path $TargetRoot "simpleLinux"
    if (-not (Test-Path -LiteralPath $qtRoot -PathType Container)) {
        Write-Host "[跳过] 包内没有 simpleLinux，跳过 Win 库目录刷新"
        return
    }

    foreach ($item in @(@{ Arch = "x64"; Tag = "X64" }, @{ Arch = "x86"; Tag = "X86" })) {
        $arch = $item.Arch
        $tag = $item.Tag

        # 动态那套：FAP.lib + FAP.dll（缺 dll 就补上 —— CMakeLists 会把 FAP.dll 部署到 exe 旁边）
        $shDst = Join-Path (Join-Path $qtRoot "shared\Win") $tag
        if (Test-Path -LiteralPath $shDst -PathType Container) {
            $hit = Find-LibSource -SdkDir $SdkDir -Kind win -Arch $arch `
                -SubDirs @("Release", "libFAP\Release") -MustContain "$LibName.dll"
            if ($hit) {
                [void](Copy-FileSafe -SrcFile (Join-Path $hit.SrcDir "$LibName.lib") -DstDir $shDst)
                [void](Copy-FileSafe -SrcFile (Join-Path $hit.SrcDir "$LibName.dll") -DstDir $shDst)
            } else {
                Write-Host "[警告] $arch 没找到动态构建目录，包内 simpleLinux\shared\Win\$tag 仍是旧库"
            }
        }

        # 静态那套：只有 FAP.lib（静态模式不需要 dll，也故意不放）
        $stDst = Join-Path (Join-Path $qtRoot "static\Win") $tag
        if (Test-Path -LiteralPath $stDst -PathType Container) {
            $hit = Find-StaticLibSource -SdkDir $SdkDir -Kind win -Arch $arch `
                -FileName "$LibName.lib" -SubDirs @("Release", "libFAP\Release")
            if ($hit) {
                [void](Copy-FileSafe -SrcFile (Join-Path $hit.SrcDir "$LibName.lib") -DstDir $stDst)
            } else {
                Write-Host "[警告] $arch 没找到静态构建目录，包内 simpleLinux\static\Win\$tag 仍是旧库"
            }
        }
    }
}

function Copy-AndroidLib {
    <#
        .SYNOPSIS
            Android 库复制：主库 + FAPAlgo + opencv/onnxruntime（从链接行解析）+ libusb/libuvc（取自 demo）。
        .DESCRIPTION
            产物布局三种形态都认（cmake-build-<abi> 顶层 / libFAP / build_temp\android\android_<abi>_*）。
    #>
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$LibName,
        [Parameter(Mandatory)][string]$TargetDir,
        [string[]]$Headers,
        # demo 的 jniLibs 里有 libusb1.0.so / libuvc0.7.so（libFAP.so 的运行时依赖），从那里补
        [string]$AndroidDir
    )
    $includeDir = Join-Path $TargetDir "include"
    New-SafeDirectory $includeDir
    if ($Headers) { Copy-Headers -SrcFiles $Headers -TargetDir $includeDir }

    $soName = "lib$LibName.so"
    foreach ($abi in @("armeabi-v7a", "arm64-v8a")) {
        # 空串 = 构建目录顶层（Android 的 .so 就落在那里）；构建入口不同，逐个探测
        $hit = Find-LibSource -SdkDir $SrcDir -Kind android -Arch $abi `
            -SubDirs @("", "libFAP") -MustContain $soName

        if (-not $hit) {
            $tried = (Get-LibBuildDirs -SdkDir $SrcDir -Kind android -Arch $abi) -join "  |  "
            Write-Host "[跳过] $abi 库源目录不存在（已尝试顶层与 libFAP）: $tried"
            continue
        }
        $src = $hit.SrcDir
        # 依赖解析（opencv/onnxruntime）要用带 ninja / link.txt 的构建目录；
        # 命中官方输出目录时那里没有链接行，得另找（否则包里少 opencv/onnx）
        $depDir = Resolve-DepBuildDir -SdkDir $SrcDir -Kind android -Arch $abi -Preferred $hit.BuildDir

        # 参考包结构：so 整组进 simpleAndroid 的 jniLibs（lib<Lib>\src\main\cpp\<abi>），
        # 不再在包根平铺 <abi> 目录（A910 G6SDK 参考包就是这样）
        $dst = Join-Path $TargetDir "simpleAndroid\lib$LibName\src\main\cpp\$abi"
        $extra = @(Get-AndroidRuntimeDeps -BuildDir $depDir)

        if ($AndroidDir) {
            $jni = Join-Path $AndroidDir "lib$LibName\src\main\cpp\$abi"
            if (Test-Path -LiteralPath $jni -PathType Container) {
                foreach ($f in @(Get-ChildItem -LiteralPath $jni -File -Filter "*.so" -ErrorAction SilentlyContinue)) {
                    $extra += $f.FullName
                }
            }
        }

        # 同上：吃掉返回值，别污染 $target
        $n = Copy-LibFiles -SrcDir $src -DstDir $dst -Kind so -ExtraFiles $extra
        Write-Host "  [$abi 运行时] $n 个 so -> $dst"

        # jniLibs 里还 checked-in 一份静态库 lib<Lib>.a（样例切 BUILD_STATIC_LIBS=ON 时用），
        # 它只随 ON 那次构建产出，.so 那趟带不到 → 单独刷新（只覆盖已存在的那个文件，不新增）
        $staDst = Join-Path $dst "lib$LibName.a"
        if (Test-Path -LiteralPath $staDst -PathType Leaf) {
            $staHit = Find-StaticLibSource -SdkDir $SrcDir -Kind android -Arch $abi `
                -FileName "lib$LibName.a" -SubDirs @("", "libFAP")
            if ($staHit) {
                [void](Copy-FileSafe -SrcFile (Join-Path $staHit.SrcDir "lib$LibName.a") -DstDir $dst)
            } else {
                Write-Host "[警告] $abi 没找到静态构建目录（android_${abi}_ON），包内 lib$LibName.a 仍是旧库"
            }
        }

        if (-not (Get-ChildItem -LiteralPath $src -File -Filter "lib*Algo*.so" -ErrorAction SilentlyContinue)) {
            Write-Host "[警告] $abi 构建目录里没有算法库（lib*Algo*.so），包内 demo 可能加载失败: $src"
        }
    }
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
        Write-Host "[提示] $QtDir 下没有独立 linux/ 预编译目录（shared\Linux\<arch> 约定的机型由 Copy-LinuxBuildLibs 处理）"
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

function Copy-LinuxBuildLibs {
    <#
        .SYNOPSIS
            把 SDK 的 Linux 构建产物（整组 .so：主库 + *Algo* + onnx/opencv）补进包内 simpleLinux 的架构目录。
        .DESCRIPTION
            *_qt 工程里 checked-in 的 shared/Linux/<arch> 是**旧库**，只有 libFAP.so + libusb/libuvc；
            算法拆成独立 .so 后必须与主库同目录（OXiAlgoLoader 从主库自身目录加载），
            所以按架构从构建产物整组拷一遍（旧的同名库被覆盖）。

            除构建目录自带的 libFAP.so / libFAPAlgo.so 外，还要补 opencv_world 与 onnxruntime ——
            这两个是**链接期**依赖，构建完不落构建目录，只在链接行里留了绝对路径（WSL 侧写的
            /mnt/d/git/3rd/... 形态），由 Get-LinuxRuntimeDeps 解析；解析不到再按第三方目录布局回退。

            架构目录经 Get-LinuxArchDirs 探测，A910 的 `linux\<arch>`、GSER 的 `shared\Linux\<arch>` 都认。
    #>
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][string]$Version,
        [string]$Prefix = ""
    )
    $qtRoot = Join-Path $TargetRoot "simpleLinux"
    if (-not (Test-Path -LiteralPath $qtRoot -PathType Container)) {
        Write-Host "[跳过] 包内没有 simpleLinux，跳过 Linux 库同步"
        return
    }
    $archDirs = Get-LinuxArchDirs -Root $qtRoot
    if ($archDirs.Count -eq 0) {
        Write-Host "[跳过] simpleLinux 下没有架构目录（linux\<arch> / shared\Linux\<arch> / <arch>），跳过 Linux 库同步"
        return
    }

    $thirdParty = Find-ThirdPartyDir -SdkDir $SdkDir

    # 包内 static\Linux\<arch> 放的也是 checked-in 的旧静态库（.a）。
    # Get-LinuxArchDirs 只认 linux\ / shared\Linux\ / <arch>，探测不到 static 这套，
    # 于是 static 下的 .a 永远是几个月前的版本（build_static=true 时客户拿到的就是旧库）。
    # 这里单独探一遍 static 下面的架构目录，与 shared 那趟并行处理。
    $staticArchDirs = Get-LinuxArchDirs -Root (Join-Path $qtRoot "static")

    foreach ($arch in @($archDirs.Keys | Sort-Object)) {
        $dst = $archDirs[$arch]
        $srcs = @(Get-LinuxBuildDirs -SdkDir $SdkDir -Version $Version -Prefix $Prefix -Arch $arch)
        $total = 0
        foreach ($s in $srcs) { $total += (Copy-LinuxLibFiles -SrcDir $s -DstDir $dst) }

        # 静态库：只拷 .a（.so 归上面的 shared 目录），构建目录里 .a/.so 是同一份产物
        if ($staticArchDirs.ContainsKey($arch)) {
            $sDst = $staticArchDirs[$arch]
            $staticCount = 0
            $staticSeen = @{}
            foreach ($s in $srcs) {
                # 两处候选目录（<outRoot> 与 build_temp）里是同一份 libFAP.a，按文件名去重只拷一次
                foreach ($f in @(Get-ChildItem -LiteralPath $s -File -Filter "*.a" -ErrorAction SilentlyContinue)) {
                    if ($staticSeen.ContainsKey($f.Name)) { continue }
                    $staticSeen[$f.Name] = $true
                    [void](Copy-FileSafe -SrcFile $f.FullName -DstDir $sDst)
                    $staticCount++
                }
            }
            if ($staticCount -gt 0) {
                Write-Host "  [$arch Linux静态库] $staticCount 个 .a -> $sDst"
            }

            # 静态包里 libFAP.a 是静态的，但**算法库仍是独立的 libFAPAlgo.so**：
            # OXiAlgoLoader 运行期 dlopen 它，且只从主库自身目录找；FAPAlgo 又动态依赖
            # opencv_world / onnxruntime。checked-in 的 static\Linux\<arch> 只有 .a + usb/uvc，
            # 于是客户按文档用静态库编完、一跑就加载不到算法库。这里把这三样一并补齐。
            # ⚠️ static 构建目录优先（同名产物在 shared 那次也会产出，但要以静态这次为准）
            $stFirst = @($srcs | Where-Object { $_ -match '[\\/]static[\\/]' })
            $stRest  = @($srcs | Where-Object { $_ -notmatch '[\\/]static[\\/]' })
            $staticSrcs = @($stFirst) + @($stRest)
            $algoSeen = @{}
            foreach ($s in $staticSrcs) {
                foreach ($f in @(Get-ChildItem -LiteralPath $s -File -Filter "lib*Algo*.so" -ErrorAction SilentlyContinue)) {
                    if ($algoSeen.ContainsKey($f.Name)) { continue }
                    $algoSeen[$f.Name] = $true
                    [void](Copy-FileSafe -SrcFile $f.FullName -DstDir $sDst)
                }
                if ($algoSeen.Count -gt 0) { break }   # 已从这一份构建拿到算法库，别再掺另一份
            }
            if ($algoSeen.Count -eq 0) {
                Write-Host "  [警告] $arch Linux 静态包里没有算法库（lib*Algo*.so），静态样例运行期会加载失败"
            }

            $sDep = 0
            foreach ($s in $staticSrcs) {
                $hasLink = (Test-Path -LiteralPath (Join-Path $s "build.ninja")) -or
                           (Test-Path -LiteralPath (Join-Path $s "CMakeFiles\FAPAlgo.dir\link.txt"))
                if (-not $hasLink) { continue }
                $sDep = Copy-LinuxRuntimeDeps -BuildDir $s -DstDir $sDst -Arch $arch -ThirdPartyDir $thirdParty
                if ($sDep -gt 0) { break }
            }
            if ($sDep -gt 0) {
                Write-Host "  [$arch Linux静态包依赖] $sDep 个 so（onnxruntime/opencv）-> $sDst"
            }
        }
        if ($total -eq 0) {
            Write-Host "[警告] $arch 没有 Linux 构建产物（已找 $($srcs.Count) 处：$($srcs -join '  |  ')），包内只有 demo 自带的旧库"
            continue
        }

        # opencv / onnxruntime：构建目录里没有，从链接行/第三方目录拿。
        # 注意依赖解析要用**真的构建过**的目录（里面才有 build.ninja），
        # shell 侧收集目录（<outRoot>\Linux\<arch>）只放了主库，拿它解析必然空。
        $depCount = 0
        foreach ($s in $srcs) {
            $hasLink = (Test-Path -LiteralPath (Join-Path $s "build.ninja")) -or
                       (Test-Path -LiteralPath (Join-Path $s "CMakeFiles\FAPAlgo.dir\link.txt"))
            if (-not $hasLink) { continue }
            $depCount = Copy-LinuxRuntimeDeps -BuildDir $s -DstDir $dst -Arch $arch -ThirdPartyDir $thirdParty
            if ($depCount -gt 0) { break }
        }
        $depNote = if ($depCount -gt 0) { "" } else { "（缺 onnxruntime/opencv 运行时库，客户机可能加载失败）" }

        $algo = @(Get-ChildItem -LiteralPath $dst -File -Filter "lib*Algo*.so" -ErrorAction SilentlyContinue)
        $note = if ($algo.Count -gt 0) { "" } else { "（缺算法库 lib*Algo*.so，客户机可能加载失败）" }
        Write-Host "  [$arch Linux库] $total 个 so -> $dst$note"
        if ($depCount -gt 0) {
            Write-Host "  [$arch Linux依赖] $depCount 个 so（onnxruntime/opencv）-> $dst"
        } else {
            Write-Host "  [警告] $arch Linux 依赖$depNote"
        }
    }
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
                # 删文档是收尾的锦上添花，不能因为它失败就判整次打包失败
                # （历史版本这里裸 Remove-Item，一次删除被拦就让整包报错）
                # ⚠️ 路径要先落变量：catch 块里的 $_ 是 ErrorRecord，不是文件对象
                $docFile = $_.FullName
                try {
                    Remove-Item -LiteralPath $docFile -Force -ErrorAction Stop
                    Write-Host "[删除旧文档] $docFile"
                } catch {
                    Write-Warning "[跳过] 旧文档删除失败，保留原样: $docFile ($($_.Exception.Message))"
                }
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
        # ⚠️ 不能写成 `$keywords = if (...) { @(...) } else { @() }`：空数组在 if 表达式里
        # 会被展开成"无输出"，结果变量是 $null，StrictMode 下 `$null.Count` 直接抛
        # PropertyNotFoundStrict（本次 GSER 只有 headers、没有 header_keyword 就踩了这个坑）。
        $keywords = @()
        if ($Config.ContainsKey('header_keyword') -and $Config.header_keyword) {
            $keywords = @($Config.header_keyword)
        }
        $headerFiles = @()
        if ($Config.ContainsKey('headers') -and $Config.headers) {
            $headerFiles = @($Config.headers)
        }

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
            # ⚠️ 顺序不能反：Copy-WinSourceCode 的 robocopy 会先删掉目标 simpleWin 整个目录，
            # 库必须等源码树拷完再写进 simpleWin\{libx86,libx64,shared\...}
            Copy-WinSourceCode -SrcDir $WinDir -TargetRoot $target
            Copy-WinLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target
            # 静态那套（simpleWin\static\lib<arch>）同样来自源码树里的旧文件，必须单独刷新
            Copy-WinStaticLibs -TargetRoot $target -SdkDir $SdkDir -LibName $Config.lib
        }
        Copy-WinExe -SrcDir $WinDir -TgRoot $target -SdkDir $SdkDir
    } else {
        Write-Host "[跳过] copy_win_lib=false：不拷贝 Win demo（库 / simpleWin 源码 / win_X86Demo、win_X64Demo 测试案例）"
    }

    # -------------------------
    # android  （copy_android_lib 控制：库 + simpleAndroid 源码 + apk 测试案例）
    # -------------------------
    if ($Config.copy_android_lib) {
        if (-not $OnlyApp) {
            # ⚠️ 同上：先拷源码树（会先删目标 simpleAndroid），再往 jniLibs 里补整组 so
            Copy-AndroidSourceCode -SrcDir $AndroidDir -TargetRoot $target
            Copy-AndroidLib -SrcDir $SdkDir -LibName $Config.lib -TargetDir $target -AndroidDir $AndroidDir
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
            # 同一份 *_qt 里的 simpleLinux\{shared,static}\Win\<arch> 也是 checked-in 旧库
            Copy-QtWinLibs -TargetRoot $target -SdkDir $SdkDir -LibName $Config.lib
            # demo 自带的 shared/Linux/<arch> 是旧库（只有主库 + usb/uvc），
            # 算法库 / onnx / opencv 必须从构建产物整组补齐，否则客户机加载失败
            Copy-LinuxBuildLibs -TargetRoot $target -SdkDir $SdkDir -Version $version -Prefix $Config.prefix
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
# ⚠️ 别用 `$h[k] = if (...) { @(...) } else { @() }`：空数组会被 if 表达式展开成"无输出"，
# 存进去的是 $null，下游 `$null.Count` 在 StrictMode 下直接抛异常。
# ⚠️ 也别先清空再判断（`$sdk['headers'] = @()` 之后再读 `$sdk.headers` 读到的就是空值）。
$rawKeywords = @()
if ($sdk.ContainsKey('header_keyword') -and $sdk.header_keyword) { $rawKeywords = @($sdk.header_keyword) }
$sdk['header_keyword'] = @($rawKeywords | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$rawHeaders = @()
if ($sdk.ContainsKey('headers') -and $sdk.headers) { $rawHeaders = @($sdk.headers) }
$sdk['headers'] = @($rawHeaders | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

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

# 显式收尾：不清 $LASTEXITCODE（robocopy 成功也返回 1），避免运行器把成功当失败
exit 0
