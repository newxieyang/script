<# 
说明：
1. 默认保留 CMake build cache
2. 使用 Ninja
3. Linux 构建由 WSL 脚本负责
4. WSL 输出直接从 D:\git\oxi\shenzhen\build 获取
5. 最终统一打包所有平台
6. 支持 -Clean
#>

# ============================================================
# 参数
# ============================================================

param (
    [switch] $Clean,
    [switch] $SkipWindows,
    [switch] $SkipAndroid,
    [switch] $SkipLinux,
    [switch] $PackageOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


# ============================================================
# 工具路径
# ============================================================
$cmakeExe = "D:\apps\CMake\bin\cmake.exe"
$ninjaExe = "D:\apps\JetBrains\CLion 2023.1.4\bin\ninja\win\x64\ninja.exe"


# ============================================================
# Android NDK
# ============================================================
$androidNdkRoot = "D:\apps\Android\Sdk\ndk\28.2.13676358"
$toolchainFile = Join-Path  $androidNdkRoot "build\cmake\android.toolchain.cmake"
$stripExe =Join-Path $androidNdkRoot "toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"


# ============================================================
# WSL
# ============================================================
$wslExe = "wsl.exe"
$wslScriptWin = "D:\git\script\ps\Build-FAP.ps1"
$wslScript = "/mnt/d/wsl/buildOXi.sh"

# ============================================================
# 项目路径
# ============================================================
$basedir =  "D:\git\oxi\shenzhen\oxiscansdk"

$baseRoot = "D:\git\oxi\shenzhen"
$RootOut =  Join-Path $baseRoot "build"
# ============================================================
# Linux / WSL 输出
# WSL 脚本：
# /mnt/d/git/oxi/shenzhen/build/
#     OXiScanV2.0.1.8/
#         linux/
#             arm/
#                 libFAP.a
#                 libFAP.so
#             x64/
#                 libFAP.a
#                 libFAP.so
# ============================================================
$androidRootOut = "D:\git\oxi\shenzhen\oxiscansdk_Android\libFAP\src\main\cpp"

# ============================================================
# Windows 临时构建目录
# ============================================================
$build_shared_x64_dir = Join-Path $RootOut "build_shared_x64"
$build_static_x64_dir = Join-Path $RootOut "build_static_x64"
$build_shared_x86_dir = Join-Path $RootOut "build_shared_x86"
$build_static_x86_dir = Join-Path $RootOut "build_static_x86"


# ============================================================
# Windows 输出目录
# ============================================================
$winRootOut = Join-Path $RootOut "Windows"
$out_shared_x64 =  Join-Path $winRootOut "x64\shared"
$out_static_x64 =  Join-Path $winRootOut "x64\static"
$out_shared_x86 =  Join-Path $winRootOut "x86\shared"
$out_static_x86 =  Join-Path $winRootOut "x86\static"


# ============================================================
# Android 临时构建目录
# ============================================================
$buildAndroidRoot = Join-Path $RootOut "Android"
$build_arm64_shared = Join-Path $RootOut "arm64-v8a_shared"
$build_arm64_static = Join-Path $RootOut "arm64-v8a_static"
$build_armv7_shared = Join-Path $RootOut "armeabi-v7a_shared"
$build_armv7_static = Join-Path $RootOut  "armeabi-v7a_static"


# ============================================================
# Android 最终输出
# ============================================================
$out_arm64 = Join-Path $androidRootOut "arm64-v8a"
$out_armv7 = Join-Path $androidRootOut "armeabi-v7a"


# ============================================================
# 工具检查
# ============================================================

function Check-Tool {

    param(
        [Parameter(Mandatory = $true)]
        [string]$path,

        [Parameter(Mandatory = $true)]
        [string]$name
    )

    if (-not (Test-Path $path)) {
        throw "$name 不存在: $path"
    }

    Write-Host "[OK] $name"
    Write-Host "     $path"
}


function Check-Command {

    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    $cmd = Get-Command $name -ErrorAction SilentlyContinue

    if (-not $cmd) {
        throw "$name 不存在，请检查 PATH"
    }

    Write-Host "[OK] $name : $($cmd.Source)"
}


function Check-AllTools {

    Write-Host ""
    Write-Host "=============================================="
    Write-Host "检查编译工具"
    Write-Host "=============================================="

    Check-Tool $cmakeExe "CMake"
    Check-Tool $ninjaExe "Ninja"

    if (-not $SkipAndroid -and -not $PackageOnly) {

        Check-Tool $toolchainFile "Android Toolchain"

        if (Test-Path $stripExe) {
            Write-Host "[OK] llvm-strip"
            Write-Host "     $stripExe"

        }
        else {
            Write-Host ""
            Write-Host "WARNING: llvm-strip 不存在"
            Write-Host "Android .so 将跳过 strip"
        }
    }


    if (-not $SkipLinux -and -not $PackageOnly) {
        Check-Command "wsl.exe"
        if (-not (Test-Path $wslScriptWin)) {
            throw "WSL build script 不存在: ${wslScriptWin} "
        }
        Write-Host "[OK] WSL build script"
        Write-Host "     ${wslScriptWin}"
    }

    Write-Host ""
}


# ============================================================
# 创建目录
# ============================================================

function Initialize-OutputDirectories {

    $dirs = @(
        $out_shared_x64
        $out_static_x64
        $out_shared_x86
        $out_static_x86
        $out_arm64
        $out_armv7
    )

    foreach ($d in $dirs) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}


# ============================================================
# 清理
#
# 默认不清理
# 只有执行：
#
# .\Build-FAP.ps1 -Clean
#
# 才删除 build cache
# ============================================================

function Clean-All {

    Write-Host ""
    Write-Host "=============================================="
    Write-Host "清理所有旧构建缓存"
    Write-Host "=============================================="


    $buildDirs = @(
        $build_shared_x64_dir
        $build_static_x64_dir
        $build_shared_x86_dir
        $build_static_x86_dir
        $buildAndroidRoot
    )


    foreach ($d in $buildDirs) {

        if (Test-Path $d) {
            Write-Host "删除:"
            Write-Host "  $d"
            Remove-Item -Recurse -Force $d
        }
    }


    # 清理源码目录中的错误 CMake Cache
    $cacheFile = Join-Path $basedir "CMakeCache.txt"
    $cacheDir = Join-Path  $basedir  "CMakeFiles"

    if (Test-Path $cacheFile) {
        Remove-Item  -Force $cacheFile -ErrorAction SilentlyContinue
    }


    if (Test-Path $cacheDir) {
        Remove-Item -Recurse -Force  $cacheDir -ErrorAction SilentlyContinue
    }


    Write-Host ""
    Write-Host "清理完成"
    Write-Host ""
}


# ============================================================
# CMake Configure
# ============================================================

function Invoke-CMakeConfigure {

    param(

        [Parameter(Mandatory = $true)]
        [string]$buildDir,

        [Parameter(Mandatory = $true)]
        [string[]]$arguments,

        [string]$targetName = ""
    )

    New-Item -ItemType Directory  -Force -Path $buildDir |Out-Null
    $logFile =Join-Path $buildDir "cmake-configure.log"


    Write-Host ""
    Write-Host "CMake Configure..."
    Write-Host "Target:   $targetName"
    Write-Host "BuildDir: $buildDir"


    if (Test-Path $logFile) {
        Remove-Item  $logFile -Force
    }


    $argumentString =
        (
            $arguments |
            ForEach-Object {
                if ($_ -match '[\s"]') {
                    '"' +
                    ($_ -replace '"', '\"') +
                    '"'
                }
                else {
                    $_
                }
            }
        ) -join ' '


    $cmdLine = "`"$cmakeExe`" $argumentString"
    cmd.exe /c "$cmdLine > `"$logFile`" 2>&1"
    $exitCode = $LASTEXITCODE


    if (Test-Path $logFile) {
        Get-Content $logFile |
            ForEach-Object {
                Write-Host $_
            }
    }


    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "[SUCCESS] CMake Configure"
        return
    }


    Write-Host ""
    Write-Host "=============================================="
    Write-Host "CMAKE CONFIGURE FAILED"
    Write-Host "=============================================="


    $patterns = @(
        "CMake Error"
        "error:"
        "fatal error"
        "failed"
        "Could NOT find"
    )

    $errors = Select-String -Path $logFile   -Pattern $patterns  -ErrorAction SilentlyContinue

    if ($errors) {
        Write-Host ""
        Write-Host "Error summary:"
        $errors | ForEach-Object { Write-Host $_.Line  }
    }

    Write-Host ""
    Write-Host "Full configure log:"
    Write-Host $logFile
    Write-Host "=============================================="

    throw "CMake configure failed: $targetName"
}


# ============================================================
# CMake Build
# ============================================================

function Invoke-CMakeBuild {

    param(

        [Parameter(Mandatory = $true)]
        [string]$buildDir,

        [string]$targetName = "",

        [int]$parallel = 8
    )


    $logFile =
        Join-Path `
            $buildDir `
            "cmake-build.log"


    $errorFile =
        Join-Path `
            $buildDir `
            "cmake-build-error.log"


    Write-Host ""
    Write-Host "CMake Build..."
    Write-Host "Target:   $targetName"
    Write-Host "BuildDir: $buildDir"


    if (Test-Path $logFile) {

        Remove-Item `
            $logFile `
            -Force
    }


    if (Test-Path $errorFile) {

        Remove-Item `
            $errorFile `
            -Force
    }


    & $cmakeExe `
        --build "$buildDir" `
        --config Release `
        --parallel $parallel `
        2>&1 |
        Tee-Object `
            -FilePath $logFile


    $exitCode =
        $LASTEXITCODE


    if ($exitCode -eq 0) {

        Write-Host ""
        Write-Host "[SUCCESS] CMake Build"

        return
    }


    Write-Host ""
    Write-Host "=============================================="
    Write-Host "CMAKE BUILD FAILED"
    Write-Host "=============================================="
    Write-Host "ExitCode: $exitCode"
    Write-Host ""


    $errorPatterns = @(
        "error C[0-9]+:"
        "fatal error"
        "error:"
        "LNK[0-9]+:"
        "LINK : fatal error"
        "undefined reference"
        "collect2.exe: error"
        "FAILED:"
        "ninja: build stopped"
        "CMake Error"
    )


    $errors =
        Select-String `
            -Path $logFile `
            -Pattern $errorPatterns `
            -ErrorAction SilentlyContinue


    if ($errors) {

        Write-Host "========== ERROR SUMMARY =========="


        $uniqueErrors =
            $errors |
            ForEach-Object {
                $_.Line.Trim()
            } |
            Where-Object {
                $_ -ne ""
            } |
            Select-Object -Unique


        $uniqueErrors |
            Out-File `
                -FilePath $errorFile `
                -Encoding UTF8


        foreach ($line in $uniqueErrors) {

            Write-Host $line
        }


        Write-Host ""
        Write-Host "Error log:"
        Write-Host $errorFile
    }
    else {

        Copy-Item `
            -Path $logFile `
            -Destination $errorFile `
            -Force

        Write-Host "No standard compiler error pattern found."
        Write-Host "Please check:"
        Write-Host $logFile
    }

    throw "CMake build failed: $targetName"
}


# ============================================================
# Windows 编译
# ============================================================

function Build-WinTarget {

    param(

        [string]$buildDir,

        [ValidateSet("ON", "OFF")]
        [string]$isStatic,

        [ValidateSet("x64", "x86")]
        [string]$arch,

        [string]$outDir
    )


    if ($isStatic -eq "ON") {

        $libType = "Static"

    }
    else {

        $libType = "Shared"
    }


    Write-Host ""
    Write-Host "=============================================="
    Write-Host "Windows $arch $libType"
    Write-Host "=============================================="


    New-Item `
        -ItemType Directory `
        -Force `
        -Path $buildDir |
        Out-Null


    if ($arch -eq "x64") {
        $cmakeArch = "x64"
    }
    else {
        $cmakeArch = "Win32"
    }


    $cmakeArgs = @(
        "-S", $basedir
        "-B", $buildDir
        "-G", "Visual Studio 16 2019"
        "-A", $cmakeArch
        "-DBUILD_STATIC_LIBS=$isStatic"
    )


    Invoke-CMakeConfigure `
        -buildDir $buildDir `
        -arguments $cmakeArgs `
        -targetName "Windows $arch $libType"


    Invoke-CMakeBuild `
        -buildDir $buildDir `
        -targetName "Windows $arch $libType" `
        -parallel 8


    # ========================================================
    # 查找产物
    # ========================================================

    if ($isStatic -eq "ON") {

        $libFiles = @(
            Get-ChildItem -Path $buildDir -Recurse -Filter "FAP.lib"
        )

        if ($libFiles.Count -eq 0) {
            throw  "Windows $arch Static: FAP.lib not found"
        }

        Copy-Item -Path $libFiles[0].FullName -Destination $outDir  -Force

    }
    else {

        $dllFiles = @(
            Get-ChildItem -Path $buildDir -Recurse -Filter "FAP.dll"
        )

        $libFiles = @(
            Get-ChildItem -Path $buildDir -Recurse -Filter "FAP.lib"
        )

        if ($dllFiles.Count -eq 0) {
            throw  "Windows $arch Shared: FAP.dll not found"
        }

        if ($libFiles.Count -eq 0) {
            throw  "Windows $arch Shared: FAP.lib not found"
        }

        Copy-Item -Path $dllFiles[0].FullName -Destination $outDir -Force
        Copy-Item -Path $libFiles[0].FullName -Destination $outDir  -Force
    }


    Write-Host ""
    Write-Host "[SUCCESS] Windows $arch $libType"
}


# ============================================================
# Android 编译
# ============================================================

function Build-AndroidTarget {

    param(

        [string]$abiName,

        [string]$buildDir,

        [ValidateSet("ON", "OFF")]
        [string]$isStatic,

        [string]$outDir
    )


    if ($isStatic -eq "ON") {

        $libType = "Static"

    }
    else {

        $libType = "Shared"
    }


    Write-Host ""
    Write-Host "=============================================="
    Write-Host "Android $abiName $libType"
    Write-Host "=============================================="

    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

    $cmakeArgs = @(
        "-S", $basedir
        "-B", $buildDir
        "-G", "Ninja"
        "-DCMAKE_MAKE_PROGRAM=$ninjaExe"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DANDROID_STL=c++_shared"
        "-DANDROID_PLATFORM=android-28"
        "-DCMAKE_TOOLCHAIN_FILE=$toolchainFile"
        "-DANDROID_ABI=$abiName"
        "-DBUILD_STATIC_LIBS=$isStatic"
    )


    Invoke-CMakeConfigure -buildDir $buildDir -arguments $cmakeArgs -targetName "Android $abiName $libType"
    Invoke-CMakeBuild -buildDir $buildDir  -targetName "Android $abiName $libType"  -parallel 8


    # ========================================================
    # 查找产物
    # ========================================================

    if ($isStatic -eq "ON") {
        $libName = "libFAP.a"

    }
    else {
        $libName = "libFAP.so"
    }

    $libFiles = @(
        Get-ChildItem -Path $buildDir -Recurse -Filter $libName
    )

    if ($libFiles.Count -eq 0) {
        throw "Android ${abiName} ${libType}: ${libName} not found"
    }

    $libFile = $libFiles[0]
    $targetFile =Join-Path $outDir $libName


    Write-Host "Copy:"
    Write-Host "  $($libFile.FullName)"
    Write-Host "  ->"
    Write-Host "  $targetFile"

    Copy-Item  -Path $libFile.FullName -Destination $targetFile -Force


    # ========================================================
    # Strip
    # ========================================================

    if (
        $isStatic -eq "OFF" -and
        (Test-Path $stripExe)
    ) {
        Write-Host "Strip: $targetFile"

        & $stripExe "$targetFile"
        if ($LASTEXITCODE -ne 0) {

            throw "llvm-strip failed: $targetFile"
        }
    }


    Write-Host ""
    Write-Host "[SUCCESS] Android $abiName $libType"
}


# ============================================================
# WSL Linux 编译
# ============================================================

function Invoke-WSLLinuxBuild {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Linux Build - WSL"
    Write-Host "============================================================"


    if (-not (Test-Path $wslScriptWin)) {
        throw "WSL build script 不存在: $wslScriptWin"
    }


    Write-Host ""
    Write-Host "WSL script:"
    Write-Host "  $wslScript"


    Write-Host ""
    Write-Host "Start Linux build..."


    # --------------------------------------------------------
    # 调用：
    #
    # wsl.exe bash -lc "bash '/mnt/d/git/script/build-oxiscan.sh'"
    # --------------------------------------------------------
    & $wslExe bash -lc "bash '$wslScript'"
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "WSL Linux build failed. Exit code: $exitCode"
    }

    Write-Host ""
    Write-Host "[SUCCESS] WSL Linux build finished."
}


# ============================================================
# 获取 Linux 最新版本目录
#
# 例如：
#
# D:\git\oxi\shenzhen\build\
#     OXiScanV2.0.1.8
#     OXiScanV2.0.1.9
#
# 自动选择最新修改的 OXiScanV*
# ============================================================

function Get-LinuxVersionDirectory {

    if (-not (Test-Path $linuxBuildRoot)) {
        throw "Linux build root 不存在: $linuxBuildRoot"
    }

    $dirs = @(
        Get-ChildItem -Path $linuxBuildRoot -Directory -Filter "OXiScanV*"
    )

    if ($dirs.Count -eq 0) {
        throw  "没有找到 Linux 构建版本目录: $linuxBuildRoot"
    }

    $latest = $dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    Write-Host ""
    Write-Host "Linux Version Directory:"
    Write-Host "  $($latest.FullName)"

    return $latest.FullName
}


# ============================================================
# Linux 产物检查
# ============================================================

function Get-LinuxArtifacts {

    param(
        [string]$versionDir
    )

    $armRoot = Join-Path $versionDir "linux\arm"
    $x64Root = Join-Path $versionDir "linux\x64"


    $artifacts = @(
        @{
            Name = "Linux ARM64 Static"
            Path = Join-Path $armRoot "libFAP.a"
        }

        @{
            Name = "Linux ARM64 Shared"
            Path = Join-Path $armRoot "libFAP.so"
        }

        @{
            Name = "Linux x64 Static"
            Path = Join-Path $x64Root "libFAP.a"
        }

        @{
            Name = "Linux x64 Shared"
            Path = Join-Path $x64Root "libFAP.so"
        }
    )


    foreach ($item in $artifacts) {
        if (-not (Test-Path $item.Path)) {
            throw "$($item.Name) 不存在: $($item.Path)"
        }

        Write-Host "[OK] $($item.Name)"
        Write-Host "     $($item.Path)"
    }


    return $artifacts
}


# ============================================================
# 创建最终 Package
# ============================================================

function New-SDKPackage {

    param(
        [string]$linuxVersionDir
    )


    Write-Host ""
    Write-Host "============================================================"
    Write-Host "开始打包 SDK"
    Write-Host "============================================================"


    # ========================================================
    # 版本
    # ========================================================
    $leaf =Split-Path $linuxVersionDir -Leaf
    # OXiScanV2.0.1.8
    $version = $leaf -replace "^OXiScanV", ""

    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = "unknown"
    }

    $packageRoot = Join-Path $baseRoot "sdk_release\OXiScanSDK_v$version"
    $zipFile = Join-Path $baseRoot  "sdk_release\OXiScanSDK_v$version.zip"


    # ========================================================
    # 如果已经存在，删除旧 Package
    # ========================================================

    if (Test-Path $packageRoot) {
        Write-Host "删除旧 Package:"
        Write-Host "  $packageRoot"
        Remove-Item -Recurse -Force $packageRoot
    }

    if (Test-Path $zipFile) {
        Write-Host "删除旧 ZIP:"
        Write-Host "  $zipFile"
        Remove-Item -Force $zipFile
    }

    New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null


    # ========================================================
    # 创建目录结构
    # ========================================================

    $packageDirs = @(

        "include"

        "windows\x64\shared"
        "windows\x64\static"

        "windows\x86\shared"
        "windows\x86\static"

        "android\arm64-v8a\shared"
        "android\arm64-v8a\static"

        "android\armeabi-v7a\shared"
        "android\armeabi-v7a\static"

        "linux\x64\shared"
        "linux\x64\static"

        "linux\arm64\shared"
        "linux\arm64\static"

        "doc"

        "windows_demo"

        "android_demo"
    )


    foreach ($dir in $packageDirs) {

        New-Item `
            -ItemType Directory `
            -Force `
            -Path (Join-Path $packageRoot $dir) |
            Out-Null
    }


    # ========================================================
    # Headers
    # 默认从：
    # oxiscansdk/include
    # ========================================================
    $includeSource = Join-Path $basedir "include"


    if (Test-Path $includeSource) {
        Write-Host ""
        Write-Host "Copy headers..."

        Copy-Item `
            -Path "$includeSource\*" `
            -Destination `
                (Join-Path $packageRoot "include") `
            -Recurse `
            -Force
    }
    else {

        Write-Host ""
        Write-Host "WARNING: include 目录不存在:"
        Write-Host "  $includeSource"
    }


    # ========================================================
    # Windows
    # ========================================================

    Write-Host ""
    Write-Host "Copy Windows libraries..."


    Copy-Item `
        -Path "$out_shared_x64\*" `
        -Destination `
            (Join-Path $packageRoot "windows\x64\shared") `
        -Recurse `
        -Force


    Copy-Item `
        -Path "$out_static_x64\*" `
        -Destination `
            (Join-Path $packageRoot "windows\x64\static") `
        -Recurse `
        -Force


    Copy-Item `
        -Path "$out_shared_x86\*" `
        -Destination `
            (Join-Path $packageRoot "windows\x86\shared") `
        -Recurse `
        -Force


    Copy-Item `
        -Path "$out_static_x86\*" `
        -Destination `
            (Join-Path $packageRoot "windows\x86\static") `
        -Recurse `
        -Force


    # ========================================================
    # Android
    # ========================================================

    Write-Host ""
    Write-Host "Copy Android libraries..."


    # arm64 shared
    if (Test-Path (Join-Path $out_arm64 "libFAP.so")) {

        Copy-Item `
            (Join-Path $out_arm64 "libFAP.so") `
            (Join-Path `
                $packageRoot `
                "android\arm64-v8a\shared") `
            -Force
    }


    # arm64 static
    if (Test-Path (Join-Path $out_arm64 "libFAP.a")) {

        Copy-Item `
            (Join-Path $out_arm64 "libFAP.a") `
            (Join-Path `
                $packageRoot `
                "android\arm64-v8a\static") `
            -Force
    }


    # armv7 shared
    if (Test-Path (Join-Path $out_armv7 "libFAP.so")) {

        Copy-Item `
            (Join-Path $out_armv7 "libFAP.so") `
            (Join-Path `
                $packageRoot `
                "android\armeabi-v7a\shared") `
            -Force
    }


    # armv7 static
    if (Test-Path (Join-Path $out_armv7 "libFAP.a")) {

        Copy-Item `
            (Join-Path $out_armv7 "libFAP.a") `
            (Join-Path `
                $packageRoot `
                "android\armeabi-v7a\static") `
            -Force
    }


    # ========================================================
    # Linux
    # ========================================================

    Write-Host ""
    Write-Host "Copy Linux libraries..."

    $linuxArmRoot = Join-Path $linuxVersionDir "linux\arm"
    $linuxX64Root = Join-Path $linuxVersionDir "linux\x64"

    # ARM64 static
    Copy-Item (Join-Path $linuxArmRoot "libFAP.a") (Join-Path $packageRoot "linux\arm64\static") -Force


    # ARM64 shared
    Copy-Item `
        (Join-Path $linuxArmRoot "libFAP.so") `
        (Join-Path $packageRoot "linux\arm64\shared") -Force


    # x64 static
    Copy-Item `
        (Join-Path $linuxX64Root "libFAP.a") `
        (Join-Path $packageRoot"linux\x64\static") -Force


    # x64 shared
    Copy-Item `
        (Join-Path $linuxX64Root "libFAP.so") `
        (Join-Path $packageRoot "linux\x64\shared") -Force


    # ========================================================
    # 可选文档
    # ========================================================
    $docSource = Join-Path  $basedir "doc"

    if (Test-Path $docSource) {
        Write-Host ""
        Write-Host "Copy documentation..."
        Copy-Item -Path "$docSource\*" -Destination (Join-Path $packageRoot "doc") -Recurse -Force
    }

    # ========================================================
    # ZIP
    # ========================================================
    $sdkReleaseRoot = Split-Path $packageRoot -Parent


    New-Item `
        -ItemType Directory `
        -Force `
        -Path $sdkReleaseRoot |
        Out-Null


    Write-Host ""
    Write-Host "压缩 SDK..."


    Compress-Archive `
        -Path $packageRoot `
        -DestinationPath $zipFile `
        -Force


    Write-Host ""
    Write-Host "============================================================"
    Write-Host "SDK 打包完成"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "Package:"
    Write-Host "  $packageRoot"

    Write-Host ""
    Write-Host "ZIP:"
    Write-Host "  $zipFile"


    return @{
        Version     = $version
        PackageRoot = $packageRoot
        ZipFile     = $zipFile
    }
}


# ============================================================
# 检查最终 Windows / Android / Linux 产物
# ============================================================

function Verify-Artifact {

    param(
        [string]$name,
        [string]$path
    )


    if (-not (Test-Path $path)) {
        throw   "[VERIFY FAILED] $name : $path"
    }


    $item = Get-Item $path


    if ($item.Length -le 0) {
        throw  "[VERIFY FAILED] $name 文件大小为 0: $path"
    }


    Write-Host "[OK] $name"
    Write-Host "     $path"
    Write-Host "     Size: $([Math]::Round($item.Length / 1MB, 2)) MB"
}


function Verify-AllArtifacts {

    param(
        [string]$linuxVersionDir
    )


    Write-Host ""
    Write-Host "============================================================"
    Write-Host "检查所有编译产物"
    Write-Host "============================================================"


    # Windows

    Verify-Artifact `
        "Windows x64 Shared DLL" `
        (Join-Path $out_shared_x64 "FAP.dll")


    Verify-Artifact `
        "Windows x64 Shared LIB" `
        (Join-Path $out_shared_x64 "FAP.lib")


    Verify-Artifact `
        "Windows x64 Static LIB" `
        (Join-Path $out_static_x64 "FAP.lib")


    Verify-Artifact `
        "Windows x86 Shared DLL" `
        (Join-Path $out_shared_x86 "FAP.dll")


    Verify-Artifact `
        "Windows x86 Shared LIB" `
        (Join-Path $out_shared_x86 "FAP.lib")


    Verify-Artifact `
        "Windows x86 Static LIB" `
        (Join-Path $out_static_x86 "FAP.lib")


    # Android

    Verify-Artifact `
        "Android arm64 Shared" `
        (Join-Path $out_arm64 "libFAP.so")


    Verify-Artifact `
        "Android arm64 Static" `
        (Join-Path $out_arm64 "libFAP.a")


    Verify-Artifact `
        "Android armeabi-v7a Shared" `
        (Join-Path $out_armv7 "libFAP.so")


    Verify-Artifact `
        "Android armeabi-v7a Static" `
        (Join-Path $out_armv7 "libFAP.a")


    # Linux

    Verify-Artifact `
        "Linux ARM64 Shared" `
        (Join-Path `
            $linuxVersionDir `
            "linux\arm\libFAP.so")


    Verify-Artifact `
        "Linux ARM64 Static" `
        (Join-Path `
            $linuxVersionDir `
            "linux\arm\libFAP.a")


    Verify-Artifact `
        "Linux x64 Shared" `
        (Join-Path `
            $linuxVersionDir `
            "linux\x64\libFAP.so")


    Verify-Artifact `
        "Linux x64 Static" `
        (Join-Path `
            $linuxVersionDir `
            "linux\x64\libFAP.a")


    Write-Host ""
    Write-Host "[SUCCESS] 所有产物检查通过"
}


# 输出目录内容
function Show-OutputSummary {
    param(
        [string]$linuxVersionDir
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "编译产物汇总"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "[Windows x64 Shared]"
    Get-ChildItem   $out_shared_x64 |  Select-Object Name, Length

    Write-Host ""
    Write-Host "[Windows x64 Static]"
    Get-ChildItem  $out_static_x64 | Select-Object Name, Length


    Write-Host ""
    Write-Host "[Windows x86 Shared]"
    Get-ChildItem $out_shared_x86 | Select-Object Name, Length


    Write-Host ""
    Write-Host "[Windows x86 Static]"
    Get-ChildItem $out_static_x86 | Select-Object Name, Length


    Write-Host ""
    Write-Host "[Android arm64-v8a]"
    Get-ChildItem  $out_arm64 |Select-Object Name, Length


    Write-Host ""
    Write-Host "[Android armeabi-v7a]"
    Get-ChildItem $out_armv7 | Select-Object Name, Length


    Write-Host ""
    Write-Host "[Linux ARM64]"
    Get-ChildItem (Join-Path $linuxVersionDir "linux\arm") | Select-Object Name, Length


    Write-Host ""
    Write-Host "[Linux x64]"
    Get-ChildItem (Join-Path $linuxVersionDir "linux\x64") | Select-Object Name, Length
}


# ============================================================
# Main
# ============================================================

$startTime = Get-Date

Write-Host ""
Write-Host "============================================================"
Write-Host "              OXiScan SDK Build System"
Write-Host "============================================================"
Write-Host ""
Write-Host "开始时间: $startTime"
Write-Host "源码目录: $basedir"
Write-Host ""

# PackageOnly
if ($PackageOnly) {
    Write-Host "PackageOnly 模式"
    $linuxVersionDir =  Get-LinuxVersionDirectory

    Verify-AllArtifacts  -linuxVersionDir $linuxVersionDir

    $packageInfo =  New-SDKPackage -linuxVersionDir $linuxVersionDir

    Write-Host ""
    Write-Host "PackageOnly 完成"

    exit 0
}

# 工具检查
Check-AllTools

# 创建目录
Initialize-OutputDirectories

# Clean
if ($Clean) {
    Clean-All
}
else {
    Write-Host ""
    Write-Host "保留已有 CMake build cache"
    Write-Host "如需完全清理，请使用:"
    Write-Host ""
    Write-Host "  .\Build-FAP.ps1 -Clean"
    Write-Host ""
}


# ============================================================
# Windows
# ============================================================
if (-not $SkipWindows) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "                    WINDOWS BUILD"
    Write-Host "============================================================"


    # x64 Shared
    Build-WinTarget `
        -buildDir $build_shared_x64_dir `
        -isStatic OFF `
        -arch x64 `
        -outDir $out_shared_x64

    # x64 Static
    Build-WinTarget `
        -buildDir $build_static_x64_dir `
        -isStatic ON `
        -arch x64 `
        -outDir $out_static_x64

    # x86 Shared
    Build-WinTarget `
        -buildDir $build_shared_x86_dir `
        -isStatic OFF `
        -arch x86 `
        -outDir $out_shared_x86

    # x86 Static
    Build-WinTarget `
        -buildDir $build_static_x86_dir `
        -isStatic ON `
        -arch x86 `
        -outDir $out_static_x86
}
else {
    Write-Host ""
    Write-Host "[SKIP] Windows"
}


# ============================================================
# Android
# ============================================================

if (-not $SkipAndroid) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "                    ANDROID BUILD"
    Write-Host "============================================================"

    # arm64 Shared
    Build-AndroidTarget `
        -abiName "arm64-v8a" `
        -buildDir $build_arm64_shared `
        -isStatic OFF `
        -outDir $out_arm64


    # arm64 Static
    Build-AndroidTarget `
        -abiName "arm64-v8a" `
        -buildDir $build_arm64_static `
        -isStatic ON `
        -outDir $out_arm64


    # armeabi-v7a Shared
    Build-AndroidTarget `
        -abiName "armeabi-v7a" `
        -buildDir $build_armv7_shared `
        -isStatic OFF `
        -outDir $out_armv7

    Build-AndroidTarget `
        -abiName "armeabi-v7a" `
        -buildDir $build_armv7_static `
        -isStatic ON `
        -outDir $out_armv7
}
else {

    Write-Host ""
    Write-Host "[SKIP] Android"
}

# Linux / WSL
if (-not $SkipLinux) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "                    LINUX BUILD"
    Write-Host "============================================================"
    Invoke-WSLLinuxBuild
}
else {

    Write-Host ""
    Write-Host "[SKIP] Linux"
}


# 查找 Linux 版本
$linuxVersionDir = Get-LinuxVersionDirectory

# 检查所有产物
Verify-AllArtifacts -linuxVersionDir $linuxVersionDir

# 显示汇总
Show-OutputSummary -linuxVersionDir $linuxVersionDir

# 打包 
$packageInfo =  New-SDKPackage -linuxVersionDir $linuxVersionDir
 
# 时间统计
$endTime =  Get-Date
$elapsed = $endTime - $startTime


Write-Host ""
Write-Host "============================================================"
Write-Host "                 OXiScan SDK 构建完成"
Write-Host "============================================================"

Write-Host ""
Write-Host "开始时间:"
Write-Host "  $startTime"

Write-Host ""
Write-Host "结束时间:"
Write-Host "  $endTime"

Write-Host ""
Write-Host "耗时:"
Write-Host "  $elapsed"

Write-Host ""
Write-Host "SDK:"
Write-Host "  $($packageInfo.PackageRoot)"

Write-Host ""
Write-Host "ZIP:"
Write-Host "  $($packageInfo.ZipFile)"

Write-Host ""
Write-Host "============================================================"
Write-Host "                    BUILD SUCCESS"
Write-Host "============================================================"