<#
.SYNOPSIS
OXiScan SDK 一键编译脚本

Windows:
    x86/x64
    动态库：dll + lib
    静态库：lib

Android:
    arm64-v8a
    armeabi-v7a
    动态库：libFAP.so
    静态库：libFAP.a

Android 动态库和静态库输出到同一个 ABI 目录
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# 工具路径
# ============================================================

$cmakeExe = "D:\apps\CMake\bin\cmake.exe"

$ninjaExe = "D:\apps\JetBrains\CLion 2023.1.4\bin\ninja\win\x64\ninja.exe"

$toolchainFile =
    "D:\apps\Android\Sdk\ndk\25.2.9519653\build\cmake\android.toolchain.cmake"

$stripExe =
    "D:\apps\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"


# ============================================================
# 项目源码 & 输出路径
# ============================================================

$basedir =  "D:\git\oxi\shenzhen\oxiscansdk"
$winRootOut = "D:\git\oxi\shenzhen\oxiscansdk_win"
$androidRootOut =  "D:\git\oxi\shenzhen\oxiscansdk_Android\libFAP\src\main\cpp"


# ============================================================
# Windows 临时构建目录
# ============================================================

$build_shared_x64_dir =  Join-Path $basedir "build_shared_x64"
$build_static_x64_dir =  Join-Path $basedir "build_static_x64"
$build_shared_x86_dir = Join-Path $basedir "build_shared_x86"
$build_static_x86_dir = Join-Path $basedir "build_static_x86"


# ============================================================
# Windows 输出目录
# ============================================================

$out_shared_x64 = Join-Path $winRootOut "shared\libx64"
$out_static_x64 = Join-Path $winRootOut "static\libx64"
$out_shared_x86 =  Join-Path $winRootOut "shared\libx86"
$out_static_x86 =  Join-Path $winRootOut "static\libx86"


# ============================================================
# Android 构建临时目录
# ============================================================

$buildAndroidRoot = Join-Path $basedir "build_android"
$build_arm64_shared =  Join-Path $buildAndroidRoot "arm64-v8a_shared"
$build_arm64_static =  Join-Path $buildAndroidRoot "arm64-v8a_static"
$build_armv7_shared =  Join-Path $buildAndroidRoot "armeabi-v7a_shared"
$build_armv7_static =  Join-Path $buildAndroidRoot "armeabi-v7a_static"

# ============================================================
# Android 最终输出目录
# ============================================================
$out_arm64 =  Join-Path $androidRootOut "arm64-v8a"
$out_armv7 =  Join-Path $androidRootOut "armeabi-v7a"

# ============================================================
# 工具检查
# ============================================================

function Check-Tool {
    param(
        [string]$path,
        [string]$name
    )

    if (-not (Test-Path $path)) {
        throw "$name 不存在: $path"
    }

    Write-Host "$name : $path"
}

Write-Host ""
Write-Host "=============================================="
Write-Host "检查编译工具"
Write-Host "=============================================="

Check-Tool $cmakeExe "CMake"
Check-Tool $ninjaExe "Ninja"
Check-Tool $toolchainFile "Android Toolchain"

if (Test-Path $stripExe) {
    Write-Host "llvm-strip : $stripExe"
}
else {
    Write-Host "WARNING: llvm-strip 不存在，将跳过 strip"
}

Write-Host ""


# ============================================================
# 创建输出目录
# ============================================================

$allOutDirs = @(
    $out_shared_x64
    $out_static_x64
    $out_shared_x86
    $out_static_x86
    $out_arm64
    $out_armv7
)

foreach ($d in $allOutDirs) {
    New-Item `
        -ItemType Directory `
        -Force `
        -Path $d | Out-Null
}


Write-Host "=============================================="
Write-Host "SDK源码目录:    $basedir"
Write-Host "Windows输出根:  $winRootOut"
Write-Host "Android输出根:  $androidRootOut"
Write-Host "=============================================="
Write-Host ""


# ============================================================
# 清理函数
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
            Write-Host "删除: $d"
            Remove-Item `   -Recurse `   -Force `  $d
        }
    }


    # 清理源码目录中的 CMake Cache
    $cacheFile = Join-Path $basedir "CMakeCache.txt"
    $cacheDir  = Join-Path $basedir "CMakeFiles"

    if (Test-Path $cacheFile) {
        Remove-Item `  -Force `  $cacheFile `  -ErrorAction SilentlyContinue
    }

    if (Test-Path $cacheDir) {
        Remove-Item `
            -Recurse `
            -Force `
            $cacheDir `
            -ErrorAction SilentlyContinue
    }

    Write-Host "清理完成"
    Write-Host ""
}

function Invoke-CMakeConfigure {

    param(
        [Parameter(Mandatory = $true)]
        [string]$buildDir,

        [Parameter(Mandatory = $true)]
        [string[]]$arguments,

        [Parameter(Mandatory = $false)]
        [string]$targetName = ""
    )

    $logFile = Join-Path $buildDir "cmake-configure.log"

    Write-Host ""
    Write-Host "CMake Configure..."
    Write-Host "Target:   $targetName"
    Write-Host "BuildDir: $buildDir"

    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }

    # ========================================================
    # 使用 cmd.exe 捕获 CMake 输出
    #
    # 这样不会把 stderr 的 Warning 当成
    # PowerShell NativeCommandError
    # ========================================================

    $argumentString = ($arguments | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' '

    $cmdLine = "`"$cmakeExe`" $argumentString"

    cmd.exe /c "$cmdLine > `"$logFile`" 2>&1"

    $exitCode = $LASTEXITCODE

    # 显示日志
    if (Test-Path $logFile) {
        Get-Content $logFile | ForEach-Object {
            Write-Host $_
        }
    }

    # ========================================================
    # 判断 Configure 是否成功
    # ========================================================

    if ($exitCode -eq 0) {

        Write-Host ""
        Write-Host "CMake Configure SUCCESS"

        return
    }

    # ========================================================
    # Configure 失败
    # ========================================================

    Write-Host ""
    Write-Host "=============================================="
    Write-Host "CMAKE CONFIGURE FAILED"
    Write-Host "=============================================="

    Write-Host ""
    Write-Host "Error summary:"

    $patterns = @(
        "CMake Error",
        "error:",
        "fatal error",
        "failed",
        "Could NOT find"
    )

    $errors = Select-String `
        -Path $logFile `
        -Pattern $patterns

    if ($errors) {
        $errors |
            ForEach-Object {
                Write-Host $_.Line
            }
    }
    else {
        Write-Host "No standard configure error found."
    }

    Write-Host ""
    Write-Host "Full configure log:"
    Write-Host $logFile
    Write-Host "=============================================="

    throw "CMake configure failed: $targetName"
}
# ============================================================
# CMake Build + 错误提取
# ============================================================

function Invoke-CMakeBuild {

    param(
        [Parameter(Mandatory = $true)]
        [string]$buildDir,

        [Parameter(Mandatory = $false)]
        [string]$targetName = "",

        [Parameter(Mandatory = $false)]
        [int]$parallel = 8
    )

    $logFile = Join-Path $buildDir "cmake-build.log"
    $errorFile = Join-Path $buildDir "cmake-build-error.log"

    Write-Host ""
    Write-Host "CMake Build..."

    if ($targetName -ne "") {
        Write-Host "Target: $targetName"
    }

    Write-Host "BuildDir: $buildDir"
    Write-Host "Log:     $logFile"

    # 删除旧日志
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }

    if (Test-Path $errorFile) {
        Remove-Item $errorFile -Force
    }

    # --------------------------------------------------------
    # 执行 CMake
    #
    # 2>&1:
    # stdout + stderr 合并
    #
    # Tee-Object:
    # 一边显示，一边保存日志
    # --------------------------------------------------------

    & $cmakeExe `
        --build "$buildDir" `
        --config Release `
        --parallel $parallel `
        2>&1 |
        Tee-Object -FilePath $logFile

    $exitCode = $LASTEXITCODE

    # --------------------------------------------------------
    # 构建成功
    # --------------------------------------------------------

    if ($exitCode -eq 0) {

        Write-Host ""
        Write-Host "CMake Build SUCCESS"

        return
    }

    # --------------------------------------------------------
    # 构建失败
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "=============================================="
    Write-Host "CMAKE BUILD FAILED"
    Write-Host "=============================================="
    Write-Host "ExitCode: $exitCode"
    Write-Host ""

    # --------------------------------------------------------
    # 提取错误
    # --------------------------------------------------------

    $errorPatterns = @(
        "error C[0-9]+:",
        "fatal error",
        "error:",
        "LNK[0-9]+:",
        "LINK : fatal error",
        "undefined reference",
        "collect2.exe: error",
        "FAILED:",
        "ninja: build stopped",
        "CMake Error"
    )

    $errors = Select-String `
        -Path $logFile `
        -Pattern $errorPatterns

    if ($errors) {

        Write-Host "========== ERROR SUMMARY =========="

        $uniqueErrors = $errors |
            ForEach-Object {
                $_.Line.Trim()
            } |
            Where-Object {
                $_ -ne ""
            } |
            Select-Object -Unique

        # 保存错误摘要
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

        Write-Host "No standard compiler error pattern found."

        Copy-Item `
            -Path $logFile `
            -Destination $errorFile `
            -Force

        Write-Host "Please check:"
        Write-Host $logFile
    }

    Write-Host ""
    Write-Host "Full build log:"
    Write-Host $logFile

    Write-Host "=============================================="

    throw "CMake build failed: $targetName"
}

# ============================================================
# Windows 编译函数
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
        $libType = "静态库(.lib)"
    }
    else {
        $libType = "动态库(.dll)"
    }


    Write-Host ""
    Write-Host "=============================================="
    Write-Host "构建 Windows $arch $libType"
    Write-Host "=============================================="

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $buildDir | Out-Null


    if ($arch -eq "x64") {
        $cmakeArch = "x64"
    }
    else {
        $cmakeArch = "Win32"
    }


    Write-Host "CMake Configure..."

    $cmakeArgs = @(
        "-S", $basedir,
        "-B", $buildDir,
        "-G", "Visual Studio 16 2019",
        "-A", $cmakeArch,
        "-DBUILD_STATIC_LIBS=$isStatic"
    )



  Invoke-CMakeConfigure `
    -buildDir $buildDir `
    -arguments $cmakeArgs `
    -targetName "Windows ${arch} ${libType}"

    Invoke-CMakeBuild `
    -buildDir $buildDir `
    -targetName "Windows ${arch} ${libType}" `
    -parallel 8


    Write-Host "搜索编译产物..."


    if ($isStatic -eq "ON") {

        $libFiles = @(
            Get-ChildItem `
                -Path "$buildDir" `
                -Recurse `
                -Filter "FAP.lib"
        )

        if ($libFiles.Count -eq 0) {
            throw "Windows ${arch}: FAP.lib not found"
        }

        foreach ($file in $libFiles) {

            Write-Host "拷贝: $($file.FullName)"

            Copy-Item `
                -Path $file.FullName `
                -Destination $outDir `
                -Force
        }
    }
    else {

        $dllFiles = @(
            Get-ChildItem `
                -Path "$buildDir" `
                -Recurse `
                -Filter "FAP.dll"
        )

        $libFiles = @(
            Get-ChildItem `
                -Path "$buildDir" `
                -Recurse `
                -Filter "FAP.lib"
        )


        if ($dllFiles.Count -eq 0) {
           throw "Windows ${arch}: FAP.dll not found"
        }

        if ($libFiles.Count -eq 0) {
            throw "Windows ${arch}: FAP.lib not found"
        }


        foreach ($file in $dllFiles) {

            Write-Host "拷贝: $($file.FullName)"

            Copy-Item `
                -Path $file.FullName `
                -Destination $outDir `
                -Force
        }


        foreach ($file in $libFiles) {

            Write-Host "拷贝: $($file.FullName)"

            Copy-Item `
                -Path $file.FullName `
                -Destination $outDir `
                -Force
        }
    }


    Write-Host "Windows $arch $libType 完成"
}


# ============================================================
# Android 编译函数
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
        $libType = "静态库(.a)"
    }
    else {
        $libType = "动态库(.so)"
    }


    Write-Host ""
    Write-Host "=============================================="
    Write-Host "构建 Android $abiName $libType"
    Write-Host "=============================================="

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $buildDir | Out-Null


    Write-Host "CMake Configure..."


    $cmakeArgs = @(
        "-S", $basedir,
        "-B", $buildDir,
        "-G", "Ninja",
        "-DCMAKE_MAKE_PROGRAM=$ninjaExe",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DANDROID_STL=c++_shared",
        "-DANDROID_PLATFORM=android-28",
        "-DCMAKE_TOOLCHAIN_FILE=$toolchainFile",
        "-DANDROID_ABI=$abiName",
        "-DBUILD_STATIC_LIBS=$isStatic"
    )

    Invoke-CMakeConfigure `
    -buildDir $buildDir `
    -arguments $cmakeArgs `
    -targetName "Android ${abiName} ${libType}"


   Invoke-CMakeBuild `
    -buildDir $buildDir `
    -targetName "Android ${abiName} ${libType}" `
    -parallel 8


    if ($LASTEXITCODE -ne 0) {
        throw "Android $abiName $libType 编译失败"
    }


    # ========================================================
    # 查找产物
    # ========================================================

    if ($isStatic -eq "ON") {

        $libFiles = @(
            Get-ChildItem `
                -Path "$buildDir" `
                -Recurse `
                -Filter "libFAP.a"
        )
    }
    else {

        $libFiles = @(
            Get-ChildItem `
                -Path "$buildDir" `
                -Recurse `
                -Filter "libFAP.so"
        )
    }


    if ($libFiles.Count -eq 0) {

        throw `
            "Android $abiName $libType 编译产物未找到: $buildDir"
    }


    # ========================================================
    # 如果找到多个，只使用第一个
    # ========================================================

    $libFile = $libFiles[0]

    Write-Host "找到产物:"
    Write-Host "  $($libFile.FullName)"


    # ========================================================
    # 拷贝
    # ========================================================

    $targetFile =
        Join-Path $outDir $libFile.Name


    Write-Host "拷贝:"
    Write-Host "  $targetFile"


    Copy-Item `
        -Path $libFile.FullName `
        -Destination $targetFile `
        -Force


    # ========================================================
    # Strip .so
    # ========================================================

    if (
        $isStatic -eq "OFF" -and
        (Test-Path $stripExe)
    ) {

        Write-Host "llvm-strip 精简符号: $($libFile.Name)"


        & $stripExe `
            "$targetFile"


        if ($LASTEXITCODE -ne 0) {
            throw "llvm-strip 失败: $targetFile"
        }
    }


    Write-Host "Android $abiName $libType 完成"
}


# ============================================================
# 开始编译
# ============================================================

$startTime = Get-Date

Write-Host ""
Write-Host "=============================================="
Write-Host "OXiScan SDK Build"
Write-Host "开始时间: $startTime"
Write-Host "=============================================="
Write-Host ""


Clean-All


# ============================================================
# Windows x64
# ============================================================

Build-WinTarget `
    -buildDir $build_shared_x64_dir `
    -isStatic OFF `
    -arch x64 `
    -outDir $out_shared_x64


Build-WinTarget `
    -buildDir $build_static_x64_dir `
    -isStatic ON `
    -arch x64 `
    -outDir $out_static_x64


# ============================================================
# Windows x86
# ============================================================

Build-WinTarget `
    -buildDir $build_shared_x86_dir `
    -isStatic OFF `
    -arch x86 `
    -outDir $out_shared_x86


Build-WinTarget `
    -buildDir $build_static_x86_dir `
    -isStatic ON `
    -arch x86 `
    -outDir $out_static_x86


# ============================================================
# Android arm64-v8a
# ============================================================

Build-AndroidTarget `
    -abiName "arm64-v8a" `
    -buildDir $build_arm64_shared `
    -isStatic OFF `
    -outDir $out_arm64


Build-AndroidTarget `
    -abiName "arm64-v8a" `
    -buildDir $build_arm64_static `
    -isStatic ON `
    -outDir $out_arm64


# ============================================================
# Android armeabi-v7a
# ============================================================

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


# ============================================================
# 编译完成
# ============================================================

$endTime = Get-Date
$elapsed = $endTime - $startTime


Write-Host ""
Write-Host "=============================================="
Write-Host "全部编译任务完成"
Write-Host "=============================================="

Write-Host ""
Write-Host "Windows 产物:"
Write-Host ""

Write-Host "[Windows x64 Shared]"
Get-ChildItem $out_shared_x64

Write-Host ""
Write-Host "[Windows x64 Static]"
Get-ChildItem $out_static_x64

Write-Host ""
Write-Host "[Windows x86 Shared]"
Get-ChildItem $out_shared_x86

Write-Host ""
Write-Host "[Windows x86 Static]"
Get-ChildItem $out_static_x86


Write-Host ""
Write-Host "Android 产物:"
Write-Host ""

Write-Host "[Android arm64-v8a]"
Get-ChildItem $out_arm64

Write-Host ""
Write-Host "[Android armeabi-v7a]"
Get-ChildItem $out_armv7


Write-Host ""
Write-Host "=============================================="
Write-Host "开始时间: $startTime"
Write-Host "结束时间: $endTime"
Write-Host "耗时:     $elapsed"
Write-Host "=============================================="