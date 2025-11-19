下面是在 **一台电脑上**（以 **Windows 10/11** 或 **macOS / Linux** 为例）**一键打包出 Windows、Android、Linux 三个平台库** 的完整实战方案。

> **核心目标**：  
> - **同一台电脑**（无需多台机器）  
> - **一次性运行脚本** → 输出 `Windows (.dll/.lib)` + `Android (.so)` + `Linux (.so/.a)`  
> - 支持 **静态/动态** 库  
> - 自动按 **平台 + 架构** 分目录输出

---

## 适用主机系统（任选其一）

| 主机系统 | 推荐工具 |
|--------|--------|
| **Windows 10/11** | MSVC + MinGW + Android NDK + **WSL2（用于 Linux）** |
| **macOS** | Clang + Android NDK + Homebrew |
| **Linux (Ubuntu)** | GCC + Android NDK |

> **推荐**：**Windows + WSL2**（最通用，一机三平台）

---

## 1. 环境准备（Windows + WSL2 示例）

```powershell
# 1. 安装 WSL2（Ubuntu）
wsl --install -d Ubuntu

# 2. 安装必要工具（在 Windows 终端运行）
winget install Kitware.CMake
winget install LLVM.LLVM     # 包含 clang
winget install AndroidSDK.PlatformTools

# 3. 下载 Android NDK（r26b+）
# → https://developer.android.com/ndk/downloads
# 解压到：C:\android-ndk-r26b

# 4. 安装 MinGW（用于交叉编译 Windows）
winget install msys2.msys2
# 打开 MSYS2，运行：
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake
```

```bash
# 5. 在 WSL Ubuntu 中安装
sudo apt update
sudo apt install build-essential cmake ninja-build unzip wget
```

---

## 2. 项目结构（保持不变）

```
MyLib/
├── CMakeLists.txt
├── src/foo.cpp
├── include/mylib/foo.hpp
├── toolchains/
│   ├── android-ndk.cmake
│   └── windows-mingw.cmake     # 可选
└── build_all.ps1               # Windows PowerShell 一键脚本
└── build_all.sh                # WSL / Linux 脚本
```

---

## 3. `CMakeLists.txt`（跨平台通用）

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyLib LANGUAGES CXX)

option(BUILD_SHARED_LIBS "Build shared libraries" OFF)

add_library(MyLib src/foo.cpp)
target_include_directories(MyLib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_compile_features(MyLib PUBLIC cxx_std_17)
```

---

## 4. 工具链文件

### `toolchains/android-ndk.cmake`

```cmake
set(ANDROID_PLATFORM android-21)
set(ANDROID_STL c++_shared)
include($ENV{ANDROID_NDK}/build/cmake/android.toolchain.cmake)
```

---

## 5. **一键打包脚本**（Windows PowerShell）

### `build_all.ps1`（在 Windows 运行）

```powershell
$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutRoot = "$ProjectDir/out"
$NDK = "C:\android-ndk-r26b"  # ← 改成你的路径
$WSL = "wsl"

New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null

# ============ 1. Windows (MSVC) ============
foreach ($type in "static", "shared") {
    $shared = if ($type -eq "shared") { $true } else { $false }
    $out = "$OutRoot/windows/x64/$type"
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    cmake -S $ProjectDir -B $out `
        -G "Visual Studio 17 2022" -A x64 `
        -DBUILD_SHARED_LIBS=$shared `
        -DCMAKE_BUILD_TYPE=Release
    cmake --build $out --config Release --parallel
}

# ============ 2. Android (NDK) ============
$abis = @("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
foreach ($abi in $abis) {
    foreach ($type in "static", "shared") {
        $shared = if ($type -eq "shared") { "ON" } else { "OFF" }
        $out = "$OutRoot/android/$abi/$type"
        New-Item -ItemType Directory -Force -Path $out | Out-Null
        cmake -S $ProjectDir -B $out `
            -DCMAKE_TOOLCHAIN_FILE="$ProjectDir/toolchains/android-ndk.cmake" `
            -DANDROID_ABI=$abi `
            -DANDROID_NDK=$NDK `
            -DBUILD_SHARED_LIBS=$shared `
            -DCMAKE_BUILD_TYPE=Release
        cmake --build $out --parallel
    }
}

# ============ 3. Linux (via WSL) ============
wsl bash -c "cd '$ProjectDir' && ./build_linux.sh"

Write-Host "全部完成！输出目录：$OutRoot" -ForegroundColor Green
```

---

### `build_linux.sh`（放在项目根目录，WSL 执行）

```bash
#!/usr/bin/env bash
set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_ROOT="$PROJECT_DIR/out/linux/$(uname -m)"

for type in static shared; do
  SHARED=""
  [ "$type" = "shared" ] && SHARED="-DBUILD_SHARED_LIBS=ON"
  OUT="$OUT_ROOT/$type"
  mkdir -p "$OUT"
  cmake -S "$PROJECT_DIR" -B "$OUT" \
    -DCMAKE_BUILD_TYPE=Release $SHARED
  cmake --build "$OUT" --parallel
done

echo "Linux 库已生成：$OUT_ROOT"
```

> 记得：`chmod +x build_linux.sh`

---

## 6. 一键运行（Windows）

```powershell
# 打开 PowerShell（管理员或普通均可）
cd 你的项目目录
.\build_all.ps1
```

---

## 7. 输出结果（`out/` 目录）

```
out/
├── windows/x64/
│   ├── static/MyLib.lib
│   └── shared/MyLib.dll + MyLib.lib
├── android/
│   ├── armeabi-v7a/static/libMyLib.a
│   ├── armeabi-v7a/shared/libMyLib.so
│   ├── arm64-v8a/...
│   └── ...
└── linux/x86_64/
    ├── static/libMyLib.a
    └── shared/libMyLib.so
```

---

## 8. 验证库可用性

```cpp
// test.cpp
#include <mylib/foo.hpp>
int main() { foo(); return 0; }
```

```bash
# Windows
cl test.cpp /Iinclude MyLib.lib

# Android (adb push + run)
adb push libMyLib.so /data/local/tmp/
adb shell LD_LIBRARY_PATH=/data/local/tmp /data/local/tmp/a.out

# Linux
g++ test.cpp -Iinclude -L. -lMyLib -o test && ./test
```

---

## 总结：一机三平台打包流程

| 平台 | 编译器 | 工具链 | 运行环境 |
|------|--------|--------|----------|
| **Windows** | MSVC | 原生 | Windows PowerShell |
| **Android** | NDK Clang | `android.toolchain.cmake` | Windows |
| **Linux** | GCC/Clang | 原生 | **WSL2** |

> **真正“一台电脑，一键运行”**  
> 所有依赖本地安装，无需云、虚拟机切换！

---

## 常见问题

| 问题 | 解决方案 |
|------|----------|
| `ANDROID_NDK not found` | 设置环境变量或修改脚本中的 `$NDK` 路径 |
| WSL 找不到 `cmake` | `sudo apt install cmake` |
| 动态库找不到 `.dll` | 复制到可执行目录或设置 `PATH` |
| 想打包 `.aar` | 配合 Android Gradle 使用 `cmake` |

---

**现在，你只需双击 `build_all.ps1` → 几分钟后 → 三个平台 12 个库全部搞定！**

需要我生成 **CMakePresets.json 版本** 或 **GitHub Actions CI 版本** 吗？