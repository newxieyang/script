在 C/C++ 跨平台项目中使用 **CMake** 进行**版本管理**，可以让项目在不同平台（Windows、Linux、macOS）下统一管理版本号、生成版本头文件、嵌入 Git 信息等。以下是完整的实战方案：

---

## 一、目标
- 统一管理项目版本（如 `1.2.3`）
- 自动从 Git 提取提交信息（commit hash、tag、dirty 状态）
- 生成 `version.h` 供代码使用
- 跨平台兼容（Windows、Linux、macOS）

---

## 二、项目结构示例

```
myproject/
├── CMakeLists.txt
├── src/
│   └── main.cpp
├── include/
│   └── version.h.in
└── .git/
```

---

## 三、步骤详解

### 1. 定义版本号（CMakeLists.txt）

```cmake
# CMakeLists.txt

cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES CXX)

# 主版本号（手动维护或通过 CI 注入）
set(MYPROJECT_VERSION_MAJOR 1)
set(MYPROJECT_VERSION_MINOR 2)
set(MYPROJECT_VERSION_PATCH 3)
set(MYPROJECT_VERSION_TWEAK 0)  # 可选，用于开发版本

# 完整版本字符串
set(MYPROJECT_VERSION 
    "${MYPROJECT_VERSION_MAJOR}.${MYPROJECT_VERSION_MINOR}.${MYPROJECT_VERSION_PATCH}")

# 可选：从 Git 自动获取 tag 或 commit
find_package(Git QUIET)
if(GIT_FOUND)
    # 获取最近的 tag（作为版本基准）
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --abbrev=0
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_TAG
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    # 获取 commit hash
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    # 检查是否有未提交的修改
    execute_process(
        COMMAND ${GIT_EXECUTABLE} diff-index --quiet HEAD --
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        RESULT_VARIABLE GIT_DIRTY
    )
    if(GIT_DIRTY)
        set(GIT_DIRTY_FLAG "+dirty")
    else()
        set(GIT_DIRTY_FLAG "")
    endif()
else()
    set(GIT_TAG "unknown")
    set(GIT_COMMIT_HASH "unknown")
    set(GIT_DIRTY_FLAG "")
endif()

# 构建完整版本信息
set(MYPROJECT_VERSION_FULL 
    "${MYPROJECT_VERSION}${GIT_DIRTY_FLAG}+git.${GIT_COMMIT_HASH}")
```

---

### 2. 创建版本头文件模板（`include/version.h.in`）

```cpp
// version.h.in
#pragma once

#define PROJECT_NAME            "@PROJECT_NAME@"
#define PROJECT_VERSION         "@MYPROJECT_VERSION@"
#define PROJECT_VERSION_MAJOR   @MYPROJECT_VERSION_MAJOR@
#define PROJECT_VERSION_MINOR   @MYPROJECT_VERSION_MINOR@
#define PROJECT_VERSION_PATCH   @MYPROJECT_VERSION_PATCH@
#define PROJECT_VERSION_FULL    "@MYPROJECT_VERSION_FULL@"
#define GIT_COMMIT_HASH         "@GIT_COMMIT_HASH@"
#define GIT_TAG                 "@GIT_TAG@"
#define GIT_DIRTY               "@GIT_DIRTY_FLAG@"
```

---

### 3. 生成 `version.h`

```cmake
# CMakeLists.txt 继续

# 配置 version.h
configure_file(
    "${CMAKE_SOURCE_DIR}/include/version.h.in"
    "${CMAKE_BINARY_DIR}/generated/version.h"
    @ONLY
)

# 让 IDE 能看到生成的头文件
include_directories(${CMAKE_BINARY_DIR}/generated)
```

---

### 4. 在代码中使用

```cpp
// src/main.cpp
#include <iostream>
#include "version.h"

int main() {
    std::cout << PROJECT_NAME << " v" << PROJECT_VERSION_FULL << std::endl;
    std::cout << "Git: " << GIT_COMMIT_HASH << GIT_DIRTY << std::endl;
    return 0;
}
```

---

### 5. 添加到目标

```cmake
add_executable(myapp src/main.cpp)
target_include_directories(myapp PRIVATE 
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_BINARY_DIR}/generated
)
```

---

## 四、进阶：自动从 Git Tag 推导版本（推荐 CI 使用）

```cmake
if(GIT_FOUND)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --match "v*.*.*" --dirty --always
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_DESCRIBE
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    if(GIT_DESCRIBE MATCHES "^v([0-9]+)\\.([0-9]+)\\.([0-9]+)(.*)")
        set(MYPROJECT_VERSION_MAJOR ${CMAKE_MATCH_1})
        set(MYPROJECT_VERSION_MINOR ${CMAKE_MATCH_2})
        set(MYPROJECT_VERSION_PATCH ${CMAKE_MATCH_3})
        set(MYPROJECT_VERSION_TWEAK ${CMAKE_MATCH_4})
        set(MYPROJECT_VERSION "${MYPROJECT_VERSION_MAJOR}.${MYPROJECT_VERSION_MINOR}.${MYPROJECT_VERSION_PATCH}")
        string(REGEX REPLACE "^-" "+" MYPROJECT_VERSION_TWEAK ${MYPROJECT_VERSION_TWEAK})
        set(MYPROJECT_VERSION_FULL "${MYPROJECT_VERSION}${MYPROJECT_VERSION_TWEAK}")
    endif()
endif()
```

> 使用方式：在 Git 中打 tag：`git tag -a v1.2.3 -m "Release 1.2.3"`

---

## 五、CI/CD 集成建议

```yaml
# .github/workflows/build.yml
- name: Set version from tag
  if: startsWith(github.ref, 'refs/tags/')
  run: |
    echo "MYPROJECT_VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_ENV
```

然后在 CMake 中：

```cmake
if(DEFINED ENV{MYPROJECT_VERSION})
    set(MYPROJECT_VERSION $ENV{MYPROJECT_VERSION})
endif()
```

---

## 六、跨平台注意事项

| 平台     | 注意点 |
|----------|--------|
| **Windows** | `execute_process` 在 MSYS/Git Bash 中正常 |
| **Linux/macOS** | 原生支持 |
| **IDE** | 确保 `CMAKE_BINARY_DIR/generated` 被包含 |

---

## 七、完整 CMakeLists.txt 示例（精简版）

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

# === 版本管理 ===
set(MYPROJECT_VERSION_MAJOR 1)
set(MYPROJECT_VERSION_MINOR 2)
set(MYPROJECT_VERSION_PATCH 3)
set(MYPROJECT_VERSION 
    "${MYPROJECT_VERSION_MAJOR}.${MYPROJECT_VERSION_MINOR}.${MYPROJECT_VERSION_PATCH}")

find_package(Git QUIET)
if(GIT_FOUND)
    execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
        OUTPUT_VARIABLE GIT_HASH OUTPUT_STRIP_TRAILING_WHITESPACE
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    execute_process(COMMAND ${GIT_EXECUTABLE} diff-index --quiet HEAD --
        RESULT_VARIABLE IS_DIRTY WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    if(IS_DIRTY EQUAL 0)
        set(DIRTY "")
    else()
        set(DIRTY "+dirty")
    endif()
else()
    set(GIT_HASH "unknown")
    set(DIRTY "")
endif()

set(MYPROJECT_VERSION_FULL "${MYPROJECT_VERSION}${DIRTY}+${GIT_HASH}")

configure_file(
    ${CMAKE_SOURCE_DIR}/include/version.h.in
    ${CMAKE_BINARY_DIR}/generated/version.h
    @ONLY
)

include_directories(${CMAKE_BINARY_DIR}/generated ${CMAKE_SOURCE_DIR}/include)

add_executable(myapp src/main.cpp)
```

---

## 总结

| 功能 | 实现方式 |
|------|----------|
| 手动版本 | `set(MYPROJECT_VERSION ...)` |
| Git 版本 | `git describe`, `rev-parse` |
| 生成头文件 | `configure_file(... @ONLY)` |
| 跨平台 | CMake 原生支持 |
| CI 集成 | 环境变量 + Git tag |

---

**推荐做法**：  
> 日常开发用 Git 自动版本，正式发布用 `git tag v1.2.3` + CI 注入。

如需我生成完整可运行的示例项目，也可以告诉我！