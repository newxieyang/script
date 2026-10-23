[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Encoding Fix - Final Cleanup
# copyUtils.ps1
# encoding: utf-8
# 对应 py/utils/copyUtils.py，目录名与忽略规则保持一致

. "$PSScriptRoot\fileUtils.ps1"

# ------------------------------------------------------------
# 目录名约定（与 py 一致，不要随意加版本后缀）：
#   Windows exe/dll : win_X86Demo / win_X64Demo
#   Windows 源码    : simpleWin
#   Android 源码    : simpleAndroid
#   Qt Linux 源码   : simpleLinux
# ------------------------------------------------------------

# ------------------------------------------------------------
# 单文件复制（ps / py 两侧通用）
#   放在这里而不是 ps/OXi.ps1：buildOXiAll.ps1 也 dot-source 本文件，
#   而它不加载 OXi.ps1（那是打包入口，用 & 调用）—— 定义在 OXi.ps1 里的函数它拿不到。
#   ⚠️ 有返回值：当语句调用时一律写 [void](...)，否则返回值会漏进上层函数的输出流，
#   把 $target 之类"本应是路径"的变量污染成 "True True ... 路径"。
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# 打包忽略目录（ps / py 两侧必须一致：py/utils/copyUtils.py 的 PACK_IGNORE_DIRS）
#   统一在这里定义，别在各处复制粘贴 —— 新增一类要忽略的目录只需改这一处。
#   注意：
#     * .workbuddy / .git / .idea / .vs 都是编辑器或工具目录，任何一份 SDK 都不该带
#     * cmake-build* 只能用通配：真实目录名是 cmake-build-release-vs2019_x64 之类，
#       写精确名（cmake-build-release）根本匹配不上
#     * "cmake"（无横线）不在列表里 —— A910_qt\cmake 下是 toolchain-*.cmake 源码
# ------------------------------------------------------------
function Get-PackIgnoreDirs {
    <#
        .SYNOPSIS
            按用途取"打包时要排除的子目录名"列表。
        .PARAMETER Kind
            win     : simpleWin（Windows 源码树）
            android : simpleAndroid（Android 源码树）
            qt      : simpleLinux（Qt 源码树）
            doc     : doc（文档目录）
        .OUTPUTS
            [string[]] 目录名列表；bare 名（如 .workbuddy）匹配任意层级，带 * 的按通配匹配
    #>
    param([Parameter(Mandatory)][ValidateSet("win", "android", "qt", "doc")][string]$Kind)
    switch ($Kind) {
        "win" { @("Release", "x64", ".vs", ".vscode", ".git", ".idea", ".workbuddy", "CMakeFiles", "cmake-build*") }
        "android" { @(".gradle", ".git", ".idea", ".workbuddy", ".cxx", ".artifacts", "build", "build-static", "cmake-build*") }
        "qt" { @(".git", ".idea", ".vs", ".vscode", ".workbuddy", "build", "build-static", ".cxx", "CMakeFiles", "cmake-build*") }
        "doc" { @(".git", ".workbuddy") }
    }
}

# ------------------------------------------------------------
# Windows 产物目录解析
#   同一套 demo 代码有两种工程形态，exe/dll 落点不同：
#     VS 工程   : <SdkDir>\Release                    / <SdkDir>\x64\Release
#     CMake 工程: <SdkDir>\cmake-build-release-vs2019_x86\Release
#                 <SdkDir>\cmake-build-release-vs2019_x64\Release
#   （A910_win、oxiscansdk_win_mut 这类只有 CMake 产物）
# ------------------------------------------------------------
function Get-WinDemoCandidateDirs {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][ValidateSet("x86", "x64")][string]$Arch
    )
    $vsSub    = if ($Arch -eq "x64") { "x64\Release" } else { "Release" }
    $cmakeSub = if ($Arch -eq "x64") { "cmake-build-release-vs2019_x64\Release" } else { "cmake-build-release-vs2019_x86\Release" }
    @(
        (Join-Path $SrcDir $vsSub),
        (Join-Path $SrcDir $cmakeSub)
    )
}

function Resolve-WinDemoDir {
    <#
        .SYNOPSIS
            按优先级挑出该架构下真正含有 .exe 的输出目录：
            先看 VS 的 Release / x64\Release，里面没有 .exe（或目录不存在）时，
            回退到 CMake 的 cmake-build-release-vs2019_<arch>\Release。
        .OUTPUTS
            [string] 命中的目录；候选目录都没有 .exe 时返回 $null
    #>
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][ValidateSet("x86", "x64")][string]$Arch
    )
    foreach ($dir in (Get-WinDemoCandidateDirs -SrcDir $SrcDir -Arch $Arch)) {
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        $exe = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter "*.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($exe) { return $dir }
    }
    return $null
}

function Resolve-WinDemoLibDir {
    <#
        .SYNOPSIS
            Windows demo 的库目录 —— 两种 demo 形态约定不同（BuildDemo.ps1 与 Sync 都用它）：
              * CMake demo（A910_win / oxiscansdk_win）
                    库放 shared\lib<arch>，demo 恒以 BUILD_STATIC_LIBS=OFF 动态链接
              * VS demo（MIAXIS_win / Thales_win / huantian_win）
                    vcxproj 的 AdditionalLibraryDirectories 写死 .\lib<arch>，库就在工程根
            判据是 demo 根下有没有 CMakeLists.txt（VS 工程没有）。
    #>
    param(
        [Parameter(Mandatory)][string]$DemoWin,
        [Parameter(Mandatory)][ValidateSet("x86", "x64")][string]$Arch
    )
    if (Test-Path -LiteralPath (Join-Path $DemoWin "CMakeLists.txt") -PathType Leaf) {
        return (Join-Path $DemoWin "shared\lib$Arch")
    }
    return (Join-Path $DemoWin "lib$Arch")
}

# ------------------------------------------------------------
# 库源目录解析（构建产物布局有多种形态）
#   ① CLion / 手工 cmake ：<SdkDir>\cmake-build-release-vs2019_<arch>\Release\FAP.dll
#                          <SdkDir>\cmake-build-release-<abi>\libFAP.so
#   ② 早期工程           ：<build>\libFAP\Release\FAP.dll（libFAP 还是子目录时的位置）
#   ③ 一键构建脚本       ：<SdkParent>\build_temp\win\win_<arch>_<OFF|ON>\Release\FAP.dll
#                          <SdkParent>\build_temp\android\android_<abi>_<OFF|ON>\libFAP.so
#   判定标准是"目录里真的存在主库文件"，避免选中空目录后误报"已拷贝"。
# ------------------------------------------------------------
function Get-LibBuildDirs {
    <#
        .SYNOPSIS
            给出该架构"可能存在的构建目录"列表（按优先级）。
        .DESCRIPTION
            构建入口不同 → 产物落点不同，只认 cmake-build-* 会让"一键构建后自动打包"
            整条链路拿不到库（buildOXiAll.ps1 走的是 build_temp\...）。
        .OUTPUTS
            [string[]] 构建目录（可能不存在，调用方逐个探测）
    #>
    param(
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][ValidateSet("win", "android")][string]$Kind,
        [Parameter(Mandatory)][string]$Arch
    )
    $parent = Split-Path $SdkDir -Parent
    if ($Kind -eq "win") {
        # 顺序即优先级：一键构建脚本的 build_temp（BuildWin 刚落下的**整组**：主库 + FAPAlgo +
        # opencv/onnx，同批构建、内容一定自洽）→ IDE 的 cmake-build-release-vs2019_<arch>。
        # ⚠️ 反过来（IDE 优先）会让 SDK 源仓里开发者随手编的目录胜出，而那份目录经常只有主库
        # 被刷新过，FAPAlgo / opencv 还是几个月前的旧货。2026-10-23 踩过：包里 FAPAlgo.dll
        # 停在 10-21，与 build_temp 里同批构建的那份差 2.7 万字节，客户机跑算法直接加载旧实现。
        @(
            (Join-Path $parent "build_temp\win\win_${Arch}_OFF"),
            (Join-Path $parent "build_temp\win\win_${Arch}_ON"),
            (Join-Path $SdkDir "cmake-build-release-vs2019_$Arch")
        )
    } else {
        # 官方构建输出 <sdk父>\build\<prefix><version>\Android\<abi>：BuildAndroid.ps1 把主库 +
        # 算法库整组落在那里，是"这次发布"最该用的源；IDE 的 cmake-build-* 常常是旧产物或未 strip
        # 的调试版。目录名带版本号，用通配按新到旧展开，不依赖调用方传 version。
        $official = @()
        $buildRoot = Join-Path $parent "build"
        if (Test-Path -LiteralPath $buildRoot -PathType Container) {
            foreach ($d in @(Get-ChildItem -LiteralPath $buildRoot -Directory -ErrorAction SilentlyContinue |
                    Sort-Object -Property LastWriteTimeUtc -Descending)) {
                $cand = Join-Path $d.FullName "Android\$Arch"
                if (Test-Path -LiteralPath $cand -PathType Container) { $official += $cand }
            }
        }
        # 顺序即优先级：官方输出 → 一键构建脚本的 build_temp → IDE 的 cmake-build。
        # IDE 目录排在最后，是因为它是开发者本地随手构建的，可能没 strip、也可能比发布版本旧。
        $official + @(
            (Join-Path $parent "build_temp\android\android_${Arch}_OFF"),
            (Join-Path $parent "build_temp\android\android_${Arch}_ON"),
            (Join-Path $SdkDir "cmake-build-release-$Arch")
        )
    }
}

function Resolve-LibSourceDir {
    param(
        [Parameter(Mandatory)][string]$BuildDir,
        # 空串表示构建目录顶层（Android 的 so 就落在 <build>\ 下）
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$SubDirs,
        [string]$MustContain
    )
    foreach ($sub in $SubDirs) {
        $dir = if ([string]::IsNullOrEmpty($sub)) { $BuildDir } else { Join-Path $BuildDir $sub }
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        if ($MustContain -and -not (Test-Path -LiteralPath (Join-Path $dir $MustContain) -PathType Leaf)) { continue }
        return $dir
    }
    return $null
}

function Find-LibSource {
    <#
        .SYNOPSIS
            在 Get-LibBuildDirs 给出的所有构建目录里找真正含主库的那一个。
        .PARAMETER MustContain
            主库文件名（如 FAP.dll / libFAP.so）。不传时改为"目录里至少有一个 .dll/.so"。
        .OUTPUTS
            [hashtable] @{ SrcDir = 库所在目录; BuildDir = 命中的构建目录 }；都没命中返回 $null
            （依赖解析 Get-AndroidRuntimeDeps 要用构建目录，不能用库目录）
    #>
    param(
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][ValidateSet("win", "android")][string]$Kind,
        [Parameter(Mandatory)][string]$Arch,
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$SubDirs,
        [string]$MustContain
    )
    $suffix = if ($Kind -eq "win") { ".dll" } else { ".so" }
    # 顺序优先：Get-LibBuildDirs 已经把"官方构建输出"排在 IDE 的 cmake-build-* 之前，
    # 不能按 mtime 择优 —— 官方目录里的库是拷过来的，mtime 还留着构建时间，会输给
    # 开发者后来随手用 IDE 编的那一份（未 strip、体积翻倍）。
    foreach ($bd in (Get-LibBuildDirs -SdkDir $SdkDir -Kind $Kind -Arch $Arch)) {
        $src = Resolve-LibSourceDir -BuildDir $bd -SubDirs $SubDirs -MustContain $MustContain
        if (-not $src) { continue }
        if (-not $MustContain) {
            # 没指定主库名时，用一个"真含动态库"的判定，避免选中空目录后误报已拷贝
            $any = Get-ChildItem -LiteralPath $src -File -Filter "*$suffix" -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if (-not $any) { continue }
        }
        return @{ SrcDir = $src; BuildDir = $bd }
    }
    return $null
}

function Get-StaticBuildDirs {
    <#
        .SYNOPSIS
            给出"静态产物优先"的构建目录列表（.lib / .a）。
        .DESCRIPTION
            静态库只在 BUILD_STATIC_LIBS=ON 那一次构建里产出（win_<arch>_ON / android_<abi>_ON）。
            Get-LibBuildDirs 的默认顺序是"官方 → OFF → ON"，直接拿它找 .lib/.a 会命中 OFF
            那套（那里的 FAP.lib 只是 12 KB 的导入库，不是 16 MB 的静态库）或 IDE 的旧产物。
            这里把 *_ON 提到最前，其余按原顺序兜底（IDE 静态构建也是合法来源）。
        .OUTPUTS
            [string[]] 构建目录（可能不存在，调用方逐个探测）
    #>
    param(
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][ValidateSet("win", "android")][string]$Kind,
        [Parameter(Mandatory)][string]$Arch
    )
    $all = @(Get-LibBuildDirs -SdkDir $SdkDir -Kind $Kind -Arch $Arch)
    $pref = @($all | Where-Object { $_ -match '_ON[\\/]?$' })
    return @($pref + @($all | Where-Object { $pref -notcontains $_ }))
}

function Find-StaticLibSource {
    <#
        .SYNOPSIS
            找真正含静态库（FAP.lib / libFAP.a）的那个构建目录。
        .PARAMETER FileName
            静态库文件名（`$LibName.lib` / `lib$LibName.a`）—— 与动态库同名时靠它区分形态
        .OUTPUTS
            [hashtable] @{ SrcDir = 库所在目录; BuildDir = 命中的构建目录 }；都没命中返回 $null
    #>
    param(
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][ValidateSet("win", "android")][string]$Kind,
        [Parameter(Mandatory)][string]$Arch,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$SubDirs
    )
    foreach ($bd in (Get-StaticBuildDirs -SdkDir $SdkDir -Kind $Kind -Arch $Arch)) {
        $src = Resolve-LibSourceDir -BuildDir $bd -SubDirs $SubDirs -MustContain $FileName
        if ($src) { return @{ SrcDir = $src; BuildDir = $bd } }
    }
    return $null
}

function Copy-LibFiles {
    <#
        .SYNOPSIS
            把一组动态库整批拷进目标目录（算法库 + 运行时依赖与主库同目录部署）。
        .DESCRIPTION
            FAP 运行期由 OXiAlgoLoader 从"自身所在目录"加载 FAPAlgo，FAPAlgo 又依赖 opencv / onnxruntime
            （Android 还要 libusb / libuvc）—— 少任何一个，客户机上就跑不起来，所以整组一起走。
        .PARAMETER Kind
            dll : Windows；so : Android/Linux
        .PARAMETER ExtraFiles
            目录外解析出来的依赖的绝对路径（如 Android 从链接行取到的 opencv / onnxruntime .so）
        .OUTPUTS
            [int] 实际拷贝的文件数
    #>
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$DstDir,
        [Parameter(Mandatory)][ValidateSet("dll", "so")][string]$Kind,
        [AllowEmptyCollection()][string[]]$ExtraFiles = @()
    )
    New-SafeDirectory $DstDir
    $copied = 0

    # 1) 库目录里的全部动态库（主库 + 算法库 + opencv + onnx + usb/uvc）
    foreach ($f in @(Get-ChildItem -LiteralPath $SrcDir -File -Filter "*.$Kind" -ErrorAction SilentlyContinue)) {
        Copy-Item -LiteralPath $f.FullName -Destination $DstDir -Force
        $copied++
    }

    # 2) 目录外的依赖（同名文件已在上一步拷过则跳过：目录里的版本才是这次构建真正产出的）
    foreach ($f in @($ExtraFiles)) {
        if ([string]::IsNullOrWhiteSpace($f)) { continue }
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
            Write-Host "[缺失] 运行时依赖不存在: $f"
            continue
        }
        if (Test-Path -LiteralPath (Join-Path $DstDir (Split-Path $f -Leaf))) { continue }
        Copy-Item -LiteralPath $f -Destination $DstDir -Force
        $copied++
    }
    return $copied
}

# ------------------------------------------------------------
# Linux 库目录（各 SDK 的 *_qt 工程约定并不统一，三套都要认）
#   A910_qt       : simpleLinux\arm | x64              （架构目录直接在 simpleLinux 下）
#   部分工程       : simpleLinux\linux\aarch64 | x64
#   oxiscansdk_qt : simpleLinux\shared\Linux\aarch64 | X64（注意 X64 大写）
# 判定方式 = 目录真实存在 + 子目录名能归一化成 aarch64 / x64 / arm
# ------------------------------------------------------------
function Get-LinuxArchDirs {
    <#
        .SYNOPSIS
            在 simpleLinux（或 *_qt 源码树）下探测"架构 → 库目录"映射。
        .OUTPUTS
            [hashtable] @{ aarch64 = <目录>; x64 = <目录>; arm = <目录> }，探测不到时为空表
    #>
    param([Parameter(Mandatory)][string]$Root)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $map }
    foreach ($sub in @("", "linux", "shared\Linux", "shared\linux", "Linux")) {
        $parent = if ($sub) { Join-Path $Root $sub } else { $Root }
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $parent -Directory -Force -ErrorAction SilentlyContinue)) {
            $key = $null
            if ($d.Name -imatch '^(aarch64|arm64)$') { $key = "aarch64" }
            elseif ($d.Name -imatch '^(x64|x86_64)$') { $key = "x64" }
            elseif ($d.Name -imatch '^arm$') { $key = "arm" }
            if ($key -and -not $map.ContainsKey($key)) { $map[$key] = $d.FullName }
        }
    }
    return $map
}

function Get-LinuxBuildDirs {
    <#
        .SYNOPSIS
            给出某架构 Linux 构建产物的候选目录（按优先级）。
        .DESCRIPTION
            ① shell/buildOXiAll.sh 的官方落点：<Sdk父>\build\<prefix+version>\Linux\<arch>
            ② WSL 原始构建目录兜底：<Sdk父>\build_temp\linux\<Platform>\<shared|static>\cmake-build
            只认 ① 时，若 shell 侧拷贝步骤没跑（或版本目录名不同）就一个库都拿不到。
        .OUTPUTS
            [string[]] 目录列表（可能不存在，调用方逐个探测）
    #>
    param(
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][ValidateSet("aarch64", "x64", "arm")][string]$Arch,
        [string]$Prefix = ""
    )
    $parent = Split-Path $SdkDir -Parent
    $out = @()

    $verDirName = if ($Prefix) { "$Prefix$Version" } else { $Version }
    $linuxRoot = Join-Path (Join-Path $parent "build") (Join-Path $verDirName "Linux")
    if (Test-Path -LiteralPath $linuxRoot -PathType Container) {
        foreach ($d in @(Get-ChildItem -LiteralPath $linuxRoot -Directory -Force -ErrorAction SilentlyContinue)) {
            $match = ($d.Name -ieq $Arch) `
                -or ($Arch -eq "aarch64" -and $d.Name -imatch '^(arm|arm64)$') `
                -or ($Arch -eq "x64" -and $d.Name -imatch '^(x86_64)$')
            if ($match) { $out += $d.FullName }
        }
    }

    $platform = if ($Arch -eq "x64") { "Linux-x64" } else { "Linux-ARM64" }
    foreach ($type in @("shared", "static")) {
        $out += (Join-Path (Join-Path $parent "build_temp\linux") (Join-Path $platform (Join-Path $type "cmake-build")))
    }
    return $out
}

function Copy-LinuxLibFiles {
    <#
        .SYNOPSIS
            把 Linux 构建目录里的整组动态库（主库 + *Algo* + onnx/opencv）拷进目标目录。
        .DESCRIPTION
            WSL 下建的 .so 多为符号链接（libonnxruntime.so → libonnxruntime.so.1），
            robocopy 会拷成 0 字节，所以按文件逐个 Copy-Item（跟随链接取真实内容）。
        .OUTPUTS
            [int] 实际拷贝的文件数
    #>
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$DstDir
    )
    if (-not (Test-Path -LiteralPath $SrcDir -PathType Container)) { return 0 }
    $copied = 0
    New-SafeDirectory $DstDir
    foreach ($f in @(Get-ChildItem -LiteralPath $SrcDir -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\.so(\.\d+)*$' })) {
        try {
            Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $DstDir $f.Name) -Force -ErrorAction Stop
            $copied++
        } catch {
            Write-Warning "[Linux 库] 复制失败: $($f.Name) ($($_.Exception.Message))"
        }
    }
    return $copied
}

function Find-ThirdPartyDir {
    <#
        .SYNOPSIS
            从 SDK 源目录向上找同级的 3rd 目录（第三方库根）。
        .DESCRIPTION
            <root>\A910\A910 → <root>\3rd 这种布局；找不到返回空串（调用方自行降级）。
            buildOXiAll.ps1 里有一份等价的内联实现，这里给只需要第三方路径做回退查找的场景用。
    #>
    param([Parameter(Mandatory)][string]$SdkDir)
    $cur = $SdkDir
    while (-not [string]::IsNullOrEmpty($cur)) {
        $cand = Join-Path $cur "3rd"
        if (Test-Path -LiteralPath $cand -PathType Container) { return $cand }
        $parent = Split-Path $cur -Parent
        if ($parent -eq $cur) { break }
        $cur = $parent
    }
    return ""
}

function Get-LinuxRuntimeDeps {
    <#
        .SYNOPSIS
            从 Linux 构建目录的链接行里解析 FAPAlgo 依赖的绝对路径 .so（opencv / onnxruntime）。
        .DESCRIPTION
            构建目录里只有 libFAP.so / libFAPAlgo.so 自身；opencv_world 与 onnxruntime 是**链接期**依赖，
            构建完不会落到构建目录，只在链接命令里留了绝对路径。而这两条路径由 WSL 侧 CMake 写出，
            形如 /mnt/d/git/3rd/onnxruntime-1.12.1/lib/Linux/aarch64/libonnxruntime.so —— 不是盘符开头，
            所以不能复用 Get-AndroidRuntimeDeps 的正则（那条只认 [A-Za-z]$?:）。
            解析失败时按 THIRD_PARTY_DIR 的常规布局回退纯名字查找：
              <3rd>\onnxruntime-*\lib\Linux\<arch>\libonnxruntime.so*
              <3rd>\libOpenCV*\lib\Linux\<arch>\libopencv_*.so*
        .OUTPUTS
            [string[]] Windows 绝对路径列表；解析不出来时为空（调用方打 [缺失] 提示）
    #>
    param(
        [Parameter(Mandatory)][string]$BuildDir,
        [ValidateSet("aarch64", "x64", "arm")][string]$Arch = "",
        [string]$ThirdPartyDir = ""
    )

    $ninja = Join-Path $BuildDir "build.ninja"
    $linkTxt = Join-Path $BuildDir "CMakeFiles\FAPAlgo.dir\link.txt"
    $text = $null
    if (Test-Path -LiteralPath $ninja) {
        $text = Get-Content -LiteralPath $ninja -Raw -ErrorAction SilentlyContinue
    } elseif (Test-Path -LiteralPath $linkTxt) {
        $text = Get-Content -LiteralPath $linkTxt -Raw -ErrorAction SilentlyContinue
    }

    $out = @()
    if ($text) {
        # WSL 路径（/mnt/d/...）与 Windows 路径（D:/ 或 ninja 的 D$:/）两种都要认
        foreach ($m in [regex]::Matches($text, '(?:/mnt/[A-Za-z]|[A-Za-z]\$?:)[/\\][^ "''\r\n]+\.so')) {
            $raw = $m.Value -replace '\$:', ':'          # ninja 的 D$: -> D:
            # /mnt/d/git/3rd/x.so -> D:\git\3rd\x.so（不引 Get-WinPathFromWsl：
            # 它定义在 env_paths.ps1，本文件单独 dot-source 时不一定被加载）
            $p = if ($raw -match '^/mnt/([A-Za-z])/(.*)$') {
                "$($Matches[1].ToUpper()):\$($Matches[2] -replace '/', '\')"
            } else {
                $raw -replace '/', '\'
            }
            $leaf = Split-Path $p -Leaf
            # 自身产物与 demo 侧另有来源的 usb/uvc 从链接行带过来没意义
            if ($leaf -like "libFAP*.so" -or $leaf -like "libusb*.so" -or $leaf -like "libuvc*.so") { continue }
            if (Test-Path -LiteralPath $p -PathType Leaf) {
                if ($out -notcontains $p) { $out += $p }
            }
        }
    }

    # 回退：链接行里没有（构建失败 / 静态链接 / 换了生成器）时按第三方目录的常规布局找。
    # ⚠️ 只做「每种库取一份」——第三方目录里同时躺着 onnxruntime-1.12.0/1.12.1/1.25.1 与
    # 多个 libOpenCV，全都拷进去就是版本混装（libonnxruntime.so.1 会被后拷的覆盖）。
    # 正常路径永远是链接行（版本由 CMake 决定），这里只是兜底，取目录名最大的一份。
    if ($out.Count -eq 0 -and $ThirdPartyDir -and (Test-Path -LiteralPath $ThirdPartyDir -PathType Container) -and $Arch) {
        # ⚠️ `Get-ChildItem -Path <带通配的目录>` 返回的是**目录本身**，不是目录内容，
        # 直接叠 -Filter 永远匹配不到文件；必须两段：先取目录，再逐个 -LiteralPath 列文件。
        $libDirs = @()
        foreach ($glob in @("$ThirdPartyDir\*\lib\Linux\$Arch", "$ThirdPartyDir\*\lib\linux\$Arch",
                            "$ThirdPartyDir\*\lib\$Arch")) {
            $libDirs += @(Get-ChildItem -Path $glob -Directory -Force -ErrorAction SilentlyContinue)
        }
        # Linux 工程用的是单体库 opencv_world（拆分的 opencv_core/imgproc 是 4100/4110 的旧布局，不掺和）
        foreach ($pat in @("libonnxruntime*.so*", "libopencv_world*.so*")) {
            # 按**全路径**降序 = 按库目录名降序（叶子目录名都叫 aarch64/x64，排它没用）
            foreach ($d in @($libDirs | Sort-Object -Property FullName -Descending)) {
                $files = @(Get-ChildItem -LiteralPath $d.FullName -Filter $pat -File -Force -ErrorAction SilentlyContinue)
                if ($files.Count -eq 0) { continue }
                Write-Host "  [回退] $pat 取自第三方目录: $($d.FullName)"
                foreach ($f in $files) {
                    if ($out -notcontains $f.FullName) { $out += $f.FullName }
                }
                break   # 该种类已找到，换下一种
            }
        }
    }
    return $out
}

function Copy-LinuxRuntimeDeps {
    <#
        .SYNOPSIS
            把 Linux 构建目录解析出的运行时依赖（opencv / onnxruntime）补进目标目录。
        .DESCRIPTION
            WSL 下这些 .so 常是符号链接，必须逐文件 Copy-Item 跟随链接取真实内容。
            onnxruntime 的 SONAME 依赖 libonnxruntime.so.1（如 1.12），所以同一个库的
            libX.so 与 libX.so.N 都要带上，否则客户机 dlopen 失败。
        .OUTPUTS
            [int] 实际拷贝的文件数
    #>
    param(
        [Parameter(Mandatory)][string]$BuildDir,
        [Parameter(Mandatory)][string]$DstDir,
        [ValidateSet("aarch64", "x64", "arm")][string]$Arch = "",
        [string]$ThirdPartyDir = ""
    )
    $deps = @(Get-LinuxRuntimeDeps -BuildDir $BuildDir -Arch $Arch -ThirdPartyDir $ThirdPartyDir)
    if ($deps.Count -eq 0) { return 0 }
    New-SafeDirectory $DstDir
    $copied = 0
    foreach ($p in $deps) {
        $dir = Split-Path $p -Parent
        $leaf = Split-Path $p -Leaf
        # 带同目录里的版本后缀文件（libonnxruntime.so.1.12.1 之类）
        $siblings = @($leaf)
        if ($leaf -match '^(?<base>.+?\.so)$') {
            $baseName = $Matches['base']
            $siblings += @(Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$baseName.*" } | ForEach-Object { $_.Name })
        }
        foreach ($name in $siblings) {
            $src = Join-Path $dir $name
            if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
            try {
                Copy-Item -LiteralPath $src -Destination (Join-Path $DstDir $name) -Force -ErrorAction Stop
                $copied++
            } catch {
                Write-Warning "[Linux 依赖] 复制失败: $name ($($_.Exception.Message))"
            }
        }
    }
    return $copied
}

function Resolve-DepBuildDir {
    <#
        .SYNOPSIS
            给出"能解析链接期依赖"的构建目录（必须带 build.ninja 或 FAPAlgo 的 link.txt）。
        .DESCRIPTION
            Get-LibBuildDirs 的第一位是官方输出目录 <sdk父>\build\<ver>\Android\<abi>，
            那里只有库、没有构建元数据 —— 拿它去解析 opencv / onnxruntime 会一无所获
            （表现为包里少 libopencv_java4.so / libonnxruntime.so）。
            优先用 Preferred（若它带元数据），否则在候选里挑第一个带元数据的。
        .OUTPUTS
            [string] 目录路径；都找不到时原样返回 Preferred（可能是空串）
    #>
    param(
        [Parameter(Mandatory)][string]$SdkDir,
        [Parameter(Mandatory)][ValidateSet("android")][string]$Kind,
        [Parameter(Mandatory)][string]$Arch,
        [string]$Preferred = ""
    )
    $hasMeta = {
        param($d)
        if ([string]::IsNullOrWhiteSpace($d)) { return $false }
        (Test-Path -LiteralPath (Join-Path $d "build.ninja")) -or
        (Test-Path -LiteralPath (Join-Path $d "CMakeFiles\FAPAlgo.dir\link.txt"))
    }
    if (& $hasMeta $Preferred) { return $Preferred }
    foreach ($bd in @(Get-LibBuildDirs -SdkDir $SdkDir -Kind $Kind -Arch $Arch)) {
        if (& $hasMeta $bd) { return $bd }
    }
    return $Preferred
}

function Get-AndroidRuntimeDeps {
    <#
        .SYNOPSIS
            从构建目录的链接行里解析 FAPAlgo 依赖的绝对路径 .so（opencv / onnxruntime）。
        .DESCRIPTION
            Android 的算法库以动态方式依赖 libopencv_java4.so / libonnxruntime.so，而构建目录里只有
            FAP/FAPAlgo 自身，运行时依赖散落在 THIRD_PARTY_DIR。版本（OpenCV4.6 / onnxruntime-1.12.1 …）
            只有链接行知道，所以这里直接读链接命令：
              ninja : <build>\build.ninja 里 `build libFAPAlgo.so …` 那条
              make  : <build>\CMakeFiles\FAPAlgo.dir\link.txt
        .OUTPUTS
            [string[]] 绝对路径列表；解析不出来时为空（调用方会打 [缺失] 提示）
    #>
    param([Parameter(Mandatory)][string]$BuildDir)

    $ninja = Join-Path $BuildDir "build.ninja"
    $linkTxt = Join-Path $BuildDir "CMakeFiles\FAPAlgo.dir\link.txt"
    $text = $null
    if (Test-Path -LiteralPath $ninja) {
        $text = Get-Content -LiteralPath $ninja -Raw -ErrorAction SilentlyContinue
    } elseif (Test-Path -LiteralPath $linkTxt) {
        $text = Get-Content -LiteralPath $linkTxt -Raw -ErrorAction SilentlyContinue
    }
    if (-not $text) { return @() }

    $out = @()
    # 盘符在 ninja 里写作 D$:（冒号要转义），别的生成器写 D: —— 两种都要认，
    # 只写 [A-Za-z]: 会漏掉 ninja 的全部绝对路径（依赖就全丢了）。
    foreach ($m in [regex]::Matches($text, '[A-Za-z]\$?:[/\\][^ "''\r\n]+\.so')) {
        $p = $m.Value -replace '\$:', ':'          # ninja 的 D$: -> D:
        $leaf = Split-Path $p -Leaf
        # 自身产物与 demo 侧的 usb/uvc（另有来源）不需要从链接行带
        if ($leaf -like "libFAP*.so" -or $leaf -like "libusb*.so" -or $leaf -like "libuvc*.so") { continue }
        if ($out -notcontains $p) { $out += $p }
    }
    return $out
}

function Copy-WinExe {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TgRoot,
        # 传了就把 SDK 构建产物里的运行时库（算法库 + opencv + onnxruntime）补进 demo 目录
        [string]$SdkDir
    )
    foreach ($arch in @("x86", "x64")) {
        $dst = Join-Path $TgRoot $(if ($arch -eq "x64") { "win_X64Demo" } else { "win_X86Demo" })
        $src = Resolve-WinDemoDir -SrcDir $SrcDir -Arch $arch

        if (-not $src) {
            $tried = (Get-WinDemoCandidateDirs -SrcDir $SrcDir -Arch $arch) -join "  |  "
            Write-Host "[跳过] $arch 未找到含 .exe 的输出目录，已尝试: $tried"
            continue
        }
        Write-Host "[$arch 产物目录] $src"
        Copy-FilesBySuffix -SrcRoot $src -DstDir $dst -SuffixList @(".exe", ".dll")

        # demo 是 VS 工程，产物目录里只有 exe + FAP.dll；FAPAlgo 与 opencv / onnxruntime 只在
        # SDK 的构建目录里（算法库独立成 DLL 后必须同目录部署，否则 demo 一跑就加载失败）。
        if ($SdkDir) {
            $hit = Find-LibSource -SdkDir $SdkDir -Kind win -Arch $arch -SubDirs @("Release", "libFAP\Release")
            if ($hit) {
                $n = Copy-LibFiles -SrcDir $hit.SrcDir -DstDir $dst -Kind dll
                Write-Host "  [$arch] demo 运行时库 $n 个 -> $dst"
            } else {
                Write-Host "[提示] $arch 未找到 SDK 构建产物目录，demo 只带 demo 目录里原有的 dll"
            }
        }
    }
}

function Copy-AndroidApk {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetDir
    )
    $srcApkRoot = Join-Path $SrcDir "app\build\outputs\apk\debug"
    Copy-FilesBySuffix -SrcRoot $srcApkRoot -DstDir $TargetDir -SuffixList @(".apk")
}

function Copy-WinSourceCode {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    # py: ignore_win_code（PACK_IGNORE_DIRS["win"]）
    # 排除 IDE/构建中间目录 + .workbuddy/.git 之类的工程元数据（用 Get-PackIgnoreDirs，别写死）
    $ignore = @(Get-PackIgnoreDirs -Kind win)
    $dstCode = Join-Path $TargetRoot "simpleWin"
    [void](Copy-DirectoryFiltered -SrcDir $SrcDir -DstDir $dstCode -ExcludeNames $ignore -Label "Windows源码")
}

function Copy-AndroidSourceCode {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    # py: ignore_android_code（PACK_IGNORE_DIRS["android"]）
    $ignore = @(Get-PackIgnoreDirs -Kind android)
    $dstCode = Join-Path $TargetRoot "simpleAndroid"
    [void](Copy-DirectoryFiltered -SrcDir $SrcDir -DstDir $dstCode -ExcludeNames $ignore -Label "Android源码")
}
