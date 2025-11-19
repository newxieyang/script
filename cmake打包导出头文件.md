下面给出 **CMake** 项目打包（生成包配置文件）并 **导出头文件** 的完整示例。  
假设你的项目结构如下：

```
MyLib/
├── CMakeLists.txt          # 顶层
├── include/
│   └── mylib/
│       └── foo.hpp
├── src/
│   └── foo.cpp
└── cmake/
    └── MyLibConfig.cmake.in   # （可选）包配置模板
```

---

## 1. 编写库的 `CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.14)   # 3.14+ 支持现代 target_* 特性
project(MyLib LANGUAGES CXX)

# 1. 创建库（这里是静态库，也可换成 SHARED）
add_library(MyLib STATIC
    src/foo.cpp
)

# 2. 指定头文件所在目录（编译时可见）
target_include_directories(MyLib
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>   # 安装后使用 include/
)

# 3. C++ 标准（可选）
target_compile_features(MyLib PUBLIC cxx_std_17)

# -------------------------------------------------
# 4. 安装规则（把库和头文件安装到标准位置）
# -------------------------------------------------
include(GNUInstallDirs)   # 提供 CMAKE_INSTALL_LIBDIR、CMAKE_INSTALL_INCLUDEDIR 等

install(TARGETS MyLib
        EXPORT MyLibTargets          # 导出目标集
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}  # 自动添加 include 路径
)

# 安装头文件
install(DIRECTORY include/mylib
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# -------------------------------------------------
# 5. 导出目标文件（供其他项目直接 import）
# -------------------------------------------------
install(EXPORT MyLibTargets
        FILE MyLibTargets.cmake
        NAMESPACE MyLib::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyLib
)

# -------------------------------------------------
# 6. 生成并安装包配置文件（MyLibConfig.cmake）
# -------------------------------------------------
include(CMakePackageConfigHelpers)

# 可选：使用模板生成 Config 文件
configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/MyLibConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/MyLibConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyLib
)

# 生成版本文件（支持版本兼容）
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/MyLibConfigVersion.cmake
    VERSION 1.2.3               # 替换成你的版本号
    COMPATIBILITY SameMajorVersion
)

install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/MyLibConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/MyLibConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyLib
)
```

---

## 2. `MyLibConfig.cmake.in`（模板，可省略直接写死）

```cmake
@PACKAGE_INIT@

include("${CMAKE_CURRENT_LIST_DIR}/MyLibTargets.cmake")
check_required_components(MyLib)
```

---

## 3. 构建 & 安装

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local   # 或者自定义路径
cmake --build .
sudo cmake --install .                       # 安装到 CMAKE_INSTALL_PREFIX
```

安装后目录结构大致为：

```
/usr/local/
├── include/
│   └── mylib/
│       └── foo.hpp
├── lib/
│   └── libMyLib.a
└── lib/cmake/MyLib/
    ├── MyLibConfig.cmake
    ├── MyLibConfigVersion.cmake
    └── MyLibTargets.cmake
```

---

## 4. 其他项目使用你的库（`find_package`）

```cmake
cmake_minimum_required(VERSION 3.14)
project(Consumer LANGUAGES CXX)

find_package(MyLib REQUIRED)   # 自动搜索 CMAKE_INSTALL_PREFIX/lib/cmake/MyLib

add_executable(app main.cpp)
target_link_libraries(app PRIVATE MyLib::MyLib)   # 自动带上 include 路径
```

---

## 关键点总结

| 步骤 | 作用 |
|------|------|
| `target_include_directories(... PUBLIC ...)` | 编译时自动把头文件路径加入使用者 |
| `install(TARGETS ... EXPORT ...)` | 导出目标信息（含 include 路径） |
| `install(DIRECTORY include/ ...)` | 把头文件复制到安装目录 |
| `install(EXPORT ...)` | 生成 `*-Targets.cmake`，供 `find_package` 导入 |
| `configure_package_config_file` + `write_basic_package_version_file` | 生成 `*-Config.cmake` 与版本文件，支持 `find_package(MyLib CONFIG)` |

这样，你的库即可通过 **标准 CMake 包机制** 被任意项目发现、使用，且头文件会自动出现在编译命令行里。祝编码愉快！