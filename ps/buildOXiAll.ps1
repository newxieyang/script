param (
    [string]$SdkKey = "GSER",
    [string]$ConfigFile = ""
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# sdk_config.json 默认取仓库 config/ 目录，不再写死仓库绝对路径
if ([string]::IsNullOrWhiteSpace($ConfigFile)) { $ConfigFile = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "config") "sdk_config.json" }

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

# WSL 侧入口脚本（WSL 绝对路径）—— 由 env_paths.ps1 按仓库实际位置给出，
# 不再写死在脚本里（换机器/换挂载点自动跟随）
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

    # wsl.exe 属于原生命令：非零退出码不会触发 $ErrorActionPreference = "Stop"。
    # 不显式检查的话，Linux 编不过也照样往下跑 Sync + 打包，最后交出一个
    # "构建成功"但根本没有 Linux 库的包（2026-10-20 踩过：arm64 缺 libuvc.h）。
    $LASTEXITCODE = 0
    wsl bash $WslBuildScript `
        --src-dir "$wslSdkRoot" `
        --build-root "$wslOutRoot" `
        --third-party "$wslThirdPartyDir" `
        --lib-name "$LibBaseName" `
        --build-static "$BuildStaticStr" `
        --linux-only
    if ($LASTEXITCODE -ne 0) {
        throw "Linux 构建失败（exit=$LASTEXITCODE），已中止后续同步与打包（否则会产出缺 Linux 库的包）。"
    }
} else {
    Write-Host "[1/5] Skipping Linux build."
}

# ============================================================
# 5. Build Windows
# ============================================================
if ($sdkConfig.build_windows) {
    Write-Host "`n[2/5] Building Windows libraries..."
    $LASTEXITCODE = 0
    & $BuildWinScript `
        -OutRootWsl $wslOutRoot `
        -SdkRoot $SdkRoot `
        -ThirdPartyDir $ThirdPartyDir `
        -LibBaseName $LibBaseName `
        -BuildStatic ([bool]$sdkConfig.build_static)
    if ($LASTEXITCODE -ne 0) {
        throw "Windows 构建失败（exit=$LASTEXITCODE），已中止后续同步与打包。"
    }
} else {
    Write-Host "`n[2/5] Skipping Windows build."
}

# ============================================================
# 6. Build Android
# ============================================================
if ($sdkConfig.build_android) {
    Write-Host "`n[3/5] Building Android libraries..."
    $LASTEXITCODE = 0
    & $BuildAndroidScript `
        -OutRootWsl $wslOutRoot `
        -SdkRoot $SdkRoot `
        -ThirdPartyDir $ThirdPartyDir `
        -LibBaseName $LibBaseName `
        -BuildStatic ([bool]$sdkConfig.build_static) `
        -AndroidProjectRoot $AndroidProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Android 构建失败（exit=$LASTEXITCODE），已中止后续同步与打包。"
    }
} else {
    Write-Host "`n[3/5] Skipping Android build."
}

# ============================================================
# 7. Sync Libraries to Demo Folders
# ============================================================
Write-Host "`n[4/5] Syncing artifacts to Demo directories..."

# Copy-WinExe / Copy-WinSourceCode / Copy-AndroidApk / Copy-AndroidSourceCode
# 统一由 copyUtils.ps1 提供（脚本开头已 dot-source），避免两处命名漂移

$AndroidLibSo = "lib$LibBaseName.so"
$WinDll = "$LibBaseName.dll"

# Android Sync（demo 固定动态链接：jniLibs 只装 .so，静态 .a 不再同步）
if ($sdkConfig.build_android) {
    # 主库 + 算法库 + opencv/onnxruntime + libusb/libuvc 整组同步进 jniLibs：
    # 只同步 libFAP.so 的话，demo 编出来的 apk 一跑就少库（算法库独立成 .so 后必须同目录）。
    foreach ($abi in @("armeabi-v7a", "arm64-v8a")) {
        $hit = Find-LibSource -SdkDir $SdkRoot -Kind android -Arch $abi -SubDirs @("", "libFAP") `
            -MustContain "lib$LibBaseName.so"

        if (-not $hit) {
            Write-Host "[跳过] $abi 未找到 Android 构建产物，jniLibs 保持原样"
            continue
        }
        $dst = Join-Path $DemoAndroid $abi
        # 同 OXi.ps1：库可能来自官方输出目录（没有链接行），依赖解析另找带 ninja/link.txt 的
        $depDir = Resolve-DepBuildDir -SdkDir $SdkRoot -Kind android -Arch $abi -Preferred $hit.BuildDir
        $extra = @(Get-AndroidRuntimeDeps -BuildDir $depDir)
        $n = Copy-LibFiles -SrcDir $hit.SrcDir -DstDir $dst -Kind so -ExtraFiles $extra
        Write-Host "  [SYNC] $abi 运行时库 $n 个 -> $dst"
    }
}

# Linux Sync
if ($sdkConfig.build_linux) {
    # Linux 库目录约定不统一（A910_qt = linux\<arch>，oxiscansdk_qt = shared\Linux\<arch>），
    # 原来写死 $DemoQt\Linux\<arch> 只对 A910 正确 —— GSER 同步不到，包里的库永远是旧的。
    # 这里按"源码树里已存在的架构目录"同步，一个都探测不到时才回退建 Linux\<arch>。
    $linuxArchDirs = Get-LinuxArchDirs -Root $DemoQt
    if ($linuxArchDirs.Count -eq 0) {
        $linuxArchDirs = @{
            aarch64 = (Join-Path $DemoQt "Linux\aarch64")
            x64     = (Join-Path $DemoQt "Linux\x64")
        }
    }
    $linuxPrefix = ""
    if ($sdkConfig.PSObject.Properties["prefix"]) { $linuxPrefix = $sdkConfig.prefix }
    $thirdParty = Find-ThirdPartyDir -SdkDir $SdkRoot
    foreach ($arch in @($linuxArchDirs.Keys | Sort-Object)) {
        $dst = $linuxArchDirs[$arch]
        New-SafeDirectory $dst
        $n = 0

        # shell/buildOXiAll.sh 只把主库（libFAP.so/.a）落到 <outRoot>\Linux\<arch>，
        # 算法库与 onnx/opencv 得从真正的构建目录补 —— 否则 demo 侧永远缺算法库。
        # 显式把 outRoot 排在第一位：prefix/version 拼法与 Get-LinuxBuildDirs 不一致时也不漏主库。
        $buildDirs = @((Join-Path $outRoot "Linux\$arch"))
        foreach ($bd in @(Get-LinuxBuildDirs -SdkDir $SdkRoot -Version $version -Prefix $linuxPrefix -Arch $arch)) {
            if ($buildDirs -notcontains $bd) { $buildDirs += $bd }
        }
        foreach ($bd in $buildDirs) { $n += (Copy-LinuxLibFiles -SrcDir $bd -DstDir $dst) }

        # 依赖解析要用带 build.ninja 的那个构建目录
        foreach ($bd in $buildDirs) {
            $hasLink = (Test-Path -LiteralPath (Join-Path $bd "build.ninja")) -or
                       (Test-Path -LiteralPath (Join-Path $bd "CMakeFiles\FAPAlgo.dir\link.txt"))
            if (-not $hasLink) { continue }
            $d = Copy-LinuxRuntimeDeps -BuildDir $bd -DstDir $dst -Arch $arch -ThirdPartyDir $thirdParty
            if ($d -gt 0) {
                Write-Host "  [SYNC] Linux $arch 依赖 $d 个（onnxruntime/opencv）-> $dst"
                break
            }
        }

        if ($n -eq 0) {
            Write-Host "  [SKIP] Linux $arch 没有构建产物（已找 $($buildDirs.Count) 处），保持 demo 原有库"
        } else {
            Write-Host "  [SYNC] Linux $arch 库 $n 个 -> $dst"
        }
    }
}

# Windows Sync（demo 固定动态链接：只同步 shared，静态 .lib 不再进 demo）
if ($sdkConfig.build_windows) {
    # 算法库 + opencv/onnxruntime 先补进 outRoot 的 shared（打包与本地自测都从这里取）
    foreach ($arch in @("x86", "x64")) {
        $dstShared = Join-Path $outRoot "Windows\$arch\shared"
        # 源必须是"本次构建的那整组"：build_temp\win\win_<arch>_OFF\Release 是 BuildWin 刚落下的，
        # 主库 / FAPAlgo / opencv / onnx 同批产出，内容一定自洽。
        # 不能用 Find-LibSource 的结果当首选 —— IDE 目录（cmake-build-release-vs2019_<arch>）里
        # 常常只有主库被刷新过，FAPAlgo 还停在几个月前：整组拷回会把旧算法库一路带进包
        # （2026-10-21 旧 FAP.dll 回灌、2026-10-23 旧 FAPAlgo.dll 回灌都是这条路）。
        # 所以：build_temp 优先，找不到才退回 Find-LibSource 的探测结果。
        $freshDir = Join-Path (Join-Path (Split-Path $SdkRoot -Parent) "build_temp\win") "win_${arch}_OFF\Release"
        $srcDir = $null
        if (Test-Path -LiteralPath (Join-Path $freshDir $WinDll) -PathType Leaf) {
            $srcDir = $freshDir
        } else {
            $hit = Find-LibSource -SdkDir $SdkRoot -Kind win -Arch $arch `
                -SubDirs @("Release", "libFAP\Release") -MustContain $WinDll
            if (-not $hit) { continue }
            $srcDir = $hit.SrcDir
            Write-Host "  [提示] $arch 没有本次构建产物目录，运行时库改用: $srcDir"
        }
        $n = Copy-LibFiles -SrcDir $srcDir -DstDir $dstShared -Kind dll
        Write-Host "  [SYNC] $arch 运行时库 $n 个 -> $dstShared"
    }

    # demo 固定动态链接（BuildDemo.ps1 恒传 BUILD_STATIC_LIBS=OFF），库目录由
    # Resolve-WinDemoLibDir 判定：CMake demo → shared\lib<arch>，VS demo → lib<arch>。
    # **整组**拷（主库 + FAPAlgo + opencv/onnx），否则 demo 编出来只有主库 dll，
    # 一跑就 0xc0000135。BuildWin.ps1 即使 build_static 开启也无条件编 shared，
    # 所以 outRoot\Windows\<arch>\shared 永远是本次构建的新鲜产物。
    $winLibKind = "shared"
    foreach ($arch in @("x86", "x64")) {
        $srcDir = Join-Path $outRoot "Windows\$arch\$winLibKind"
        $dstDemo = Resolve-WinDemoLibDir -DemoWin $DemoWin -Arch $arch
        if (-not (Test-Path -LiteralPath $srcDir -PathType Container)) {
            Write-Host "  [SYNC] Win $arch 没有 $winLibKind 产物目录，demo 库目录保持原样: $srcDir"
            continue
        }
        New-SafeDirectory $dstDemo
        $n = 0
        foreach ($f in @(Get-ChildItem -LiteralPath $srcDir -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @(".lib", ".dll") })) {
            [void](Copy-FileSafe -SrcFile $f.FullName -DstDir $dstDemo)
            $n++
        }
        Write-Host "  [SYNC] Win $arch 库 $n 个 -> $dstDemo"
    }
}

# ============================================================
# 7.2. Rebuild Demos (库同步完必须重编，否则包里是旧 exe / 旧 apk)
# ============================================================
Write-Host "`n[4.2/5] Rebuilding demo projects..."

$BuildDemoScript = Join-Path $PSScriptRoot "BuildDemo.ps1"
if ($sdkConfig.build_windows) {
    $LASTEXITCODE = 0
    & $BuildDemoScript -Kind win -DemoWin $DemoWin -LibBaseName $LibBaseName
    if ($LASTEXITCODE -ne 0) { throw "Windows demo 构建失败（exit=$LASTEXITCODE），终止打包（否则会打进旧 exe）" }
}
if ($sdkConfig.build_android) {
    $LASTEXITCODE = 0
    & $BuildDemoScript -Kind android -AndroidProjectRoot $AndroidProjectRoot -AndroidJniDir $DemoAndroid
    if ($LASTEXITCODE -ne 0) { throw "Android demo 构建失败（exit=$LASTEXITCODE），终止打包（否则会打进旧 apk）" }
}

# ============================================================
# 7.3. Sync runtime libs into build output dirs
#      把整组运行库灌进"已存在的构建输出目录"（exe/dll/so 旁边），让 IDE
#      （CLion/VS）里直接跑 demo 时加载的就是本次构建的新库。SDK 源仓的
#      cmake-build 目录只是 Find-LibSource 的**兜底**（build_temp 缺失时才用），
#      但顺手刷成整组新库仍值得 —— 否则那份目录会一直是"主库新、FAPAlgo 旧"的混合体，
#      谁按 mtime 直觉取库都会中招。
#      只灌已存在的目录、且目录里得有 exe 或主库（Linux 只认主库），绝不新建空目录。
# ============================================================
function Sync-RuntimeToBuildDirs {
    param(
        [Parameter(Mandatory)][string]$SrcDir,
        [Parameter(Mandatory)][string]$MarkerName,   # 主库文件名（FAP.dll / libFAP.so）
        [Parameter(Mandatory)][string]$FileExt,      # dll / so
        [Parameter(Mandatory)][string[]]$ChildPatterns,  # 构建目录名（-like 通配）
        [Parameter(Mandatory)][string[]]$Parents,    # 构建目录所在的父目录
        [Parameter(Mandatory)][string]$Label,
        [switch]$MarkerOnly                          # 只认含主库的目录（Linux 用，防止灌进 Windows 形态的构建目录）
    )
    if (-not (Test-Path -LiteralPath (Join-Path $SrcDir $MarkerName) -PathType Leaf)) { return }
    $total = 0
    foreach ($parent in $Parents) {
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue)) {
            $matched = $false
            foreach ($pat in $ChildPatterns) { if ($d.Name -like $pat) { $matched = $true; break } }
            if (-not $matched) { continue }
            # VS 生成器产物在 Release 子目录，Ninja 在目录根 —— 两处都探，按内容命中
            foreach ($t in @((Join-Path $d.FullName "Release"), $d.FullName)) {
                if (-not (Test-Path -LiteralPath $t -PathType Container)) { continue }
                $hasMarker = Test-Path -LiteralPath (Join-Path $t $MarkerName) -PathType Leaf
                if ($MarkerOnly) {
                    if (-not $hasMarker) { continue }
                } else {
                    $hasExe = @(Get-ChildItem -LiteralPath $t -File -Filter "*.exe" -ErrorAction SilentlyContinue).Count -gt 0
                    if (-not ($hasExe -or $hasMarker)) { continue }
                }
                $k = 0
                foreach ($f in @(Get-ChildItem -LiteralPath $SrcDir -File -Filter "*.$FileExt" -ErrorAction SilentlyContinue)) {
                    [void](Copy-FileSafe -SrcFile $f.FullName -DstDir $t)
                    $k++
                }
                Write-Host "  [SYNC] $Label 运行库 $k 个 -> $t"
                $total += $k
            }
        }
    }
    if ($total -eq 0) { Write-Host "  [SKIP] $Label 没有命中任何构建输出目录" }
}

Write-Host "`n[4.3/5] Syncing runtime libs into demo/SDK build output dirs..."

if ($sdkConfig.build_windows) {
    foreach ($arch in @("x86", "x64")) {
        $srcDir = Join-Path $outRoot "Windows\$arch\shared"
        Sync-RuntimeToBuildDirs -SrcDir $srcDir -MarkerName $WinDll -FileExt "dll" -Label "Win $arch" `
            -ChildPatterns @("cmake-build-release-vs2019_$arch", "win-$arch") `
            -Parents @($DemoWin, $DemoQt, (Join-Path $DemoQt "build"), $SdkRoot)
    }
}

# Linux：qt demo 若在 WSL/CLion 里编过（构建目录里已有 libFAP.so），把 [4/5] 合好的
# 整组库（主库 + 算法库 + onnx/opencv 依赖）再灌一份进构建目录。MarkerOnly 防止把
# .so 灌进 Windows 形态的 cmake-build 目录（那边只有 FAP.dll，但会有 exe）。
if ($sdkConfig.build_linux) {
    $linuxArchDirs43 = Get-LinuxArchDirs -Root $DemoQt
    foreach ($arch in @($linuxArchDirs43.Keys | Sort-Object)) {
        $mergedDir = $linuxArchDirs43[$arch]
        Sync-RuntimeToBuildDirs -SrcDir $mergedDir -MarkerName "lib$LibBaseName.so" -FileExt "so" `
            -Label "Linux $arch" -MarkerOnly `
            -ChildPatterns @("cmake-build-*") -Parents @($DemoQt)
    }
}

# Android：demo 目录就是 jniLibs（$DemoAndroid\<abi>），[4/5] 已用本次构建整组同步，
# gradle 打 apk 时从 jniLibs 取库 —— 无需再往别处灌。
if ($sdkConfig.build_android) {
    Write-Host "  [SKIP] Android jniLibs 已在 [4/5] 同步（demo 目录即 jniLibs，无需重复）"
}

# ============================================================
# 7.5. Copy Demo Source Code & Artifacts to Output
# ============================================================
Write-Host "`n[4.5/5] Copying demo source code and artifacts..."

if ($sdkConfig.build_windows) {
    # -SdkDir：把算法库与运行时依赖一并补进 demo 目录（demo 产物里只有 exe + FAP.dll）
    Copy-WinExe -SrcDir $DemoWin -TgRoot $outRoot -SdkDir $SdkRoot
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
    # 把本次使用的配置转发给打包脚本，否则 GUI/调用方传进来的 copy_*_lib、keep_latest_doc 等
    # 覆盖值到不了打包阶段（OXi.ps1 会回落到默认 config\sdk_config.json）
    & $PackageScript -SdkKey $SdkKey -ConfigFile $ConfigFile
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
