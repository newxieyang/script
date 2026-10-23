#!/usr/bin/python
# encoding:utf-8
# ============================================================
# OXi.py — SDK 打包脚本（对应 ps/OXi.ps1，**行为以 ps/OXi.ps1 为准**）
#
# 用法:
#   python OXi.py                                   # 打包 GSER
#   python OXi.py --sdk MIAXIS                      # 指定机型
#   python OXi.py --sdk MIAXIS --only-app           # 只出 App 包
#   python OXi.py --sdk A910 --suffix Static        # 包目录追加后缀
#   python OXi.py --sdk A910 --config <路径>         # 指定配置文件
#
# 输出包结构（与 ps 一致）:
#   include/            头文件（header_keyword 搜索 或 headers 指定）
#   win_X86Demo/        x86 exe+dll
#   win_X64Demo/        x64 exe+dll
#   simpleWin/          Windows 源码
#   simpleAndroid/      Android 源码
#   *.apk               Android 调试包
#   simpleLinux/        Qt Linux 源码（含 linux/ 下的预编译库，原样拷贝，不重新构建）
#   doc/                文档
#
# 拷贝开关（config/sdk_config.json，为 false 表示该平台整块不进包）:
#   copy_win_lib     ：Win 库 + simpleWin 源码 + win_X86Demo/win_X64Demo 测试案例
#   copy_android_lib ：Android 库 + simpleAndroid 源码 + *.apk 测试案例
#   copy_linux_lib   ：simpleLinux（Qt 源码 + linux/ 下的预编译库，只拷不构建）
#   should_package   ：是否由构建流程自动调用本脚本出包（手动直接调用时仅提示、不阻断）
# ============================================================

import argparse
import glob
import json
import os
import shutil
import sys

# 允许从任意工作目录直接 `python py/OXi.py` 调用（utils 是包内相对导入）
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from utils.fileUtils import (  # noqa: E402
    findFilePathNameByKeyWord,
    parse_cmake_versions,
    remove_dir,
    safe_mkdir,
)
from utils.copyUtils import (  # noqa: E402
    copy_android_apk,
    copy_android_source_code,
    copy_lib_files,
    copy_linux_lib_files,
    copy_linux_runtime_deps,
    copy_qt_linux_libs,
    copy_win_exe,
    copy_win_source_code,
    find_lib_source,
    find_qt_linux_lib_dir,
    find_static_lib_source,
    find_third_party_dir,
    get_android_runtime_deps,
    get_lib_build_dirs,
    get_linux_arch_dirs,
    get_linux_build_dirs,
    ignore_doc,
    make_pack_ignore,
    resolve_dep_build_dir,
)


# 默认配置文件：与 ps/OXi.ps1 同一份（config/sdk_config.json 是唯一真源）
DEFAULT_CONFIG = os.path.join(os.path.dirname(_HERE), "config", "sdk_config.json")

# 必填字段（对应 ps/OXi.ps1 的字段校验）
REQUIRED_FIELDS = ("name", "sdk_dir", "target_root", "prefix", "lib")

# 布尔开关（缺字段按 false 处理，与 ps 一致）
FLAG_FIELDS = (
    "copy_win_lib",
    "copy_android_lib",
    "copy_linux_lib",
    "keep_latest_doc",
    "should_package",
)


# ============================================================
# 公共函数
# ============================================================


def copy_file_safe(src_file, dst_dir):
    """
    单个文件的安全拷贝：源不存在只提示不抛异常（对应 ps 的 Copy-FileSafe）。
    返回是否复制成功。
    """
    if not os.path.isfile(src_file):
        print(f"[跳过] 文件不存在: {src_file}")
        return False

    safe_mkdir(dst_dir)
    shutil.copy2(src_file, dst_dir)
    print(f"  [复制] {os.path.basename(src_file)} -> {dst_dir}")
    return True


def _has_lib(dir_path, keyword, suffix):
    """
    目录里是否存在文件名含 keyword 且以 suffix 结尾的文件（如 Algo + .dll → FAPAlgo.dll）。

    打包后用来判断"算法库到底进没进包"，避免旧构建悄悄出一个跑不起来的包。
    """
    if not os.path.isdir(dir_path):
        return False
    return any(keyword in n and n.lower().endswith(suffix) for n in os.listdir(dir_path))


def copy_headers(src_files, target_dir):
    """
    通用头文件复制

    容错：配置里可能有空字符串 / null 条目（ps 侧同样会先过滤再判断是否为空）。
    """
    files = [s for s in (src_files or []) if str(s).strip()]
    if not files:
        print("[跳过] 头文件列表为空")
        return

    safe_mkdir(target_dir)

    for src in files:
        if not os.path.exists(src):
            print(f"[跳过] 文件不存在: {src}")
            continue

        shutil.copy2(src, target_dir)
        print(f"[复制头文件] {src}")


def copy_headers_by_keyword(src_dir, target_dir, keywords):
    """
    根据关键字搜索头文件
    """
    keys = [k for k in (keywords or []) if str(k).strip()]
    if not keys:
        print("[跳过] 关键字列表为空")
        return

    if os.path.exists(target_dir):
        remove_dir(target_dir)

    safe_mkdir(target_dir)

    for key in keys:
        fp = findFilePathNameByKeyWord(src_dir, key)

        if fp:
            shutil.copy2(fp, target_dir)
            print(f"[复制头文件] {fp}")
        else:
            print(f"[未找到] {key}")


def copy_win_lib(src_dir, lib_name, target_dir, headers=None):
    """
    Win 库复制：主库（.lib/.dll）+ 算法库 FAPAlgo + opencv / onnxruntime 运行时。

    产物布局两种形态都认（<build>\\Release 优先，<build>\\libFAP\\Release 回退）。
    FAPAlgo 与主库必须同目录：OXiAlgoLoader 的搜索顺序是 config.ini 绝对路径 → cacheDir →
    FAP 自身目录 → 系统路径，分包放会让客户机加载失败。
    对应 ps 的 Copy-WinLib。
    """

    safe_mkdir(target_dir)

    # headers
    if headers:
        copy_headers(headers, target_dir)

    for arch in ("x86", "x64"):
        # 构建入口不同 → 产物落点不同（cmake-build-* / build_temp\win\win_<arch>_*），逐个探测
        src, _build_dir = find_lib_source(
            src_dir, "win", arch,
            ("Release", os.path.join("libFAP", "Release")),
            lib_name + ".dll",
        )
        if not src:
            tried = "  |  ".join(get_lib_build_dirs(src_dir, "win", arch))
            print(f"[跳过] {arch} 库源目录不存在（已尝试 Release 与 libFAP\\Release）: {tried}")
            continue

        # 参考包结构（A910 G6SDK）：.lib 进 simpleWin\libx86|libx64，
        # 整组 dll 进 simpleWin\shared\libx86|libx64，包根不放任何库
        win_root = os.path.join(target_dir, "simpleWin")
        lib_dst = os.path.join(win_root, "libx64" if arch == "x64" else "libx86")
        bin_dst = os.path.join(
            win_root, "shared", "libx64" if arch == "x64" else "libx86"
        )

        copy_file_safe(os.path.join(src, lib_name + ".lib"), lib_dst)

        # 主库 + FAPAlgo + opencv/onnxruntime 一起拷（lib_name.dll 也在里面）
        n = copy_lib_files(src, bin_dst, "dll")
        print(f"  [{arch} 库] {lib_name}.lib -> {lib_dst}")
        print(f"  [{arch} 运行时] {n} 个 dll -> {bin_dst}")

        # 旧构建 / 没开算法的构建里没有 *Algo*.dll —— 这种包客户机上跑不起来，必须吼一声
        if not _has_lib(src, "Algo", ".dll"):
            print(f"[警告] {arch} 构建目录里没有算法库（*Algo*.dll），包内 demo 可能加载失败: {src}")


def copy_win_static_libs(target_root, sdk_dir, lib_name):
    """
    刷新包内 simpleWin\\static\\lib<arch>（静态链接那套 .lib + 运行时 dll）。

    _win demo 把静态库 checked-in 在 static\\lib<arch> 下（CMakeLists 的 GSER_LIB_DIR =
    <static|shared>/lib<arch>），源码树那趟拷贝只是原样搬旧文件；copy_win_lib 只写
    lib<arch> 与 shared\\lib<arch>，于是走 -DBUILD_STATIC_LIBS=ON 的客户拿到的永远是
    几个月前那份 FAP.lib（缺新修的导出与行为修复）。

    这里按 ON 构建产物覆盖：FAP.lib 一定刷；同目录里**已存在**的 dll 同名覆盖，
    不新增 dll 文件（该目录的 dll 没人 glob，加进去只会平白撑大包体）。
    对应 ps 的 Copy-WinStaticLibs。
    """
    for arch in ("x86", "x64"):
        dst = os.path.join(target_root, "simpleWin", "static", "lib" + arch)
        if not os.path.isdir(dst):
            print(f"[跳过] 包内没有 simpleWin/static/lib{arch}，跳过 Win 静态库刷新")
            continue

        src, _build_dir = find_static_lib_source(
            sdk_dir, "win", arch, lib_name + ".lib",
            ("Release", os.path.join("libFAP", "Release")),
        )
        if not src:
            print(f"[警告] {arch} 没找到静态构建目录（win_{arch}_ON），"
                  f"包内 simpleWin/static/lib{arch} 仍是旧库")
            continue

        copy_file_safe(os.path.join(src, lib_name + ".lib"), dst)

        dll_count = 0
        for name in sorted(os.listdir(src)):
            p = os.path.join(src, name)
            if not name.lower().endswith(".dll") or not os.path.isfile(p):
                continue
            if not os.path.isfile(os.path.join(dst, name)):
                continue
            shutil.copy2(p, os.path.join(dst, name))
            dll_count += 1
        print(f"  [{arch} 静态库] {lib_name}.lib + {dll_count} 个同名 dll -> {dst}")


def copy_qt_win_libs(target_root, sdk_dir, lib_name):
    """
    刷新包内 simpleLinux\\{shared,static}\\Win\\<X64|X86> —— Linux 样例在 Windows 上编译时用的厂商库。

    *_qt 工程把这两套 Win 库 checked-in（见 oxiscansdk_qt/CMakeLists.txt：
    GSER_LIB_DIR = ${BUILD_STATIC_LIBS?static:shared}/Win|Linux/${ARCH}）：
      shared/Win/<arch>  动态版 FAP.lib + FAP.dll
      static/Win/<arch>  静态版 FAP.lib（无 dll）
    源码树那趟拷贝原样搬旧文件 → 这里按对应构建产物覆盖，否则 Windows 上编出来的样例
    会带着几个月前的库（其中 shared/Win/X86 还缺 FAP.dll，动态模式根本跑不起来）。
    对应 ps 的 Copy-QtWinLibs。
    """
    qt_root = os.path.join(target_root, "simpleLinux")
    if not os.path.isdir(qt_root):
        print("[跳过] 包内没有 simpleLinux，跳过 Win 库目录刷新")
        return

    for arch, tag in (("x64", "X64"), ("x86", "X86")):
        # 动态那套：FAP.lib + FAP.dll（缺 dll 就补上 —— CMakeLists 会把 FAP.dll 部署到 exe 旁边）
        sh_dst = os.path.join(qt_root, "shared", "Win", tag)
        if os.path.isdir(sh_dst):
            src, _build_dir = find_lib_source(
                sdk_dir, "win", arch,
                ("Release", os.path.join("libFAP", "Release")),
                lib_name + ".dll",
            )
            if src:
                copy_file_safe(os.path.join(src, lib_name + ".lib"), sh_dst)
                copy_file_safe(os.path.join(src, lib_name + ".dll"), sh_dst)
            else:
                print(f"[警告] {arch} 没找到动态构建目录，"
                      f"包内 simpleLinux/shared/Win/{tag} 仍是旧库")

        # 静态那套：只有 FAP.lib（静态模式不需要 dll，也故意不放）
        st_dst = os.path.join(qt_root, "static", "Win", tag)
        if os.path.isdir(st_dst):
            src, _build_dir = find_static_lib_source(
                sdk_dir, "win", arch, lib_name + ".lib",
                ("Release", os.path.join("libFAP", "Release")),
            )
            if src:
                copy_file_safe(os.path.join(src, lib_name + ".lib"), st_dst)
            else:
                print(f"[警告] {arch} 没找到静态构建目录，"
                      f"包内 simpleLinux/static/Win/{tag} 仍是旧库")


def copy_android_lib(src_dir, lib_name, target_dir, headers=None, android_dir=None):
    """
    Android 库复制：主库 + FAPAlgo + opencv/onnxruntime（从链接行解析）+ libusb/libuvc（取自 demo）。

    产物布局两种形态都认（<build> 顶层优先，<build>\\libFAP 回退）。
    对应 ps 的 Copy-AndroidLib。
    """

    include_dir = os.path.join(target_dir, "include")

    safe_mkdir(include_dir)

    if headers:
        copy_headers(headers, include_dir)

    so_name = "lib" + lib_name + ".so"
    for abi in ("armeabi-v7a", "arm64-v8a"):
        # 空串 = 构建目录顶层（Android 的 .so 就落在那里）；构建入口不同，逐个探测
        src, build_dir = find_lib_source(src_dir, "android", abi, ("", "libFAP"), so_name)

        if not src:
            tried = "  |  ".join(get_lib_build_dirs(src_dir, "android", abi))
            print(f"[跳过] {abi} 库源目录不存在（已尝试顶层与 libFAP）: {tried}")
            continue
        # 依赖解析（opencv/onnxruntime）要用带 ninja / link.txt 的构建目录；
        # 命中官方输出目录时那里没有链接行，得另找（否则包里少 opencv/onnx）
        dep_dir = resolve_dep_build_dir(src_dir, "android", abi, build_dir)

        # 参考包结构：so 整组进 simpleAndroid 的 jniLibs（lib<Lib>\src\main\cpp\<abi>），
        # 不再在包根平铺 <abi> 目录
        dst = os.path.join(
            target_dir, "simpleAndroid", "lib" + lib_name, "src", "main", "cpp", abi
        )
        extra = list(get_android_runtime_deps(dep_dir))

        # demo 的 jniLibs 里有 libusb1.0.so / libuvc0.7.so（libFAP.so 的运行时依赖）
        if android_dir:
            jni = os.path.join(android_dir, "lib" + lib_name, "src", "main", "cpp", abi)
            if os.path.isdir(jni):
                for name in sorted(os.listdir(jni)):
                    if name.lower().endswith(".so"):
                        extra.append(os.path.join(jni, name))

        n = copy_lib_files(src, dst, "so", extra)
        print(f"  [{abi} 运行时] {n} 个 so -> {dst}")

        # jniLibs 里还 checked-in 一份静态库 lib<Lib>.a（样例切 BUILD_STATIC_LIBS=ON 时用），
        # 它只随 ON 那次构建产出，.so 那趟带不到 → 单独刷新（只覆盖已存在的那个文件，不新增）
        sta_dst = os.path.join(dst, "lib" + lib_name + ".a")
        if os.path.isfile(sta_dst):
            sta_src, _bd = find_static_lib_source(
                src_dir, "android", abi, "lib" + lib_name + ".a", ("", "libFAP")
            )
            if sta_src:
                copy_file_safe(os.path.join(sta_src, "lib" + lib_name + ".a"), dst)
            else:
                print(f"[警告] {abi} 没找到静态构建目录（android_{abi}_ON），"
                      f"包内 lib{lib_name}.a 仍是旧库")

        if not _has_lib(src, "Algo", ".so"):
            print(f"[警告] {abi} 构建目录里没有算法库（lib*Algo*.so），包内 demo 可能加载失败: {src}")


def copy_qt_simple_linux(qt_dir, target_root):
    """
    复制 Qt 工程到最终 SDK 的 simpleLinux 目录

    打包时排除 .git / cmake-build* 等非源码目录（见 make_pack_ignore）。
    库目录单独处理：从源码树那趟拷贝里摘出来，再交给 copy_qt_linux_libs 逐文件拷，
    避免被漏掉/拷成空文件（对应 ps 的 Copy-QtSimpleLinux）。
    """

    if not os.path.isdir(qt_dir):
        print(f"[跳过] Qt 源码目录不存在: {qt_dir}")
        return

    dst = os.path.join(target_root, "simpleLinux")
    if os.path.exists(dst):
        remove_dir(dst)

    lib_dir = find_qt_linux_lib_dir(qt_dir)
    extra = (os.path.basename(lib_dir),) if lib_dir else ()

    safe_mkdir(os.path.dirname(dst))
    shutil.copytree(qt_dir, dst, ignore=make_pack_ignore("qt", extra))
    print(f"[复制Qt Linux源码] {qt_dir} -> {dst}")

    copy_qt_linux_libs(qt_dir, dst)


def copy_linux_build_libs(target_root, sdk_dir, version, prefix=""):
    """
    把 SDK 的 Linux 构建产物（整组 .so：主库 + *Algo* + onnx/opencv）补进包内 simpleLinux 的架构目录。

    *_qt 工程里 checked-in 的 shared/Linux/<arch> 是**旧库**，只有 libFAP.so + libusb/libuvc；
    算法拆成独立 .so 后必须与主库同目录（OXiAlgoLoader 从主库自身目录加载），
    所以按架构从构建产物整组拷一遍（旧的同名库被覆盖）。
    对应 ps 的 Copy-LinuxBuildLibs。
    """
    qt_root = os.path.join(target_root, "simpleLinux")
    if not os.path.isdir(qt_root):
        print("[跳过] 包内没有 simpleLinux，跳过 Linux 库同步")
        return

    arch_dirs = get_linux_arch_dirs(qt_root)
    if not arch_dirs:
        print("[跳过] simpleLinux 下没有架构目录（linux\\<arch> / shared\\Linux\\<arch> / <arch>），跳过 Linux 库同步")
        return

    third_party = find_third_party_dir(sdk_dir)
    # 包内 static/Linux/<arch> 放的也是 checked-in 的旧静态库（.a）。
    # get_linux_arch_dirs 只认 linux/ 、shared/Linux/ 、<arch>，探测不到 static 这套，
    # 于是 static 下的 .a 永远是几个月前的版本（build_static=true 时客户拿到的就是旧库）。
    static_arch_dirs = get_linux_arch_dirs(os.path.join(qt_root, "static"))

    for arch in sorted(arch_dirs):
        dst = arch_dirs[arch]
        srcs = get_linux_build_dirs(sdk_dir, version, arch, prefix)
        total = 0
        for src in srcs:
            total += copy_linux_lib_files(src, dst)

        # 静态库：只拷 .a（.so 归上面的 shared 目录），构建目录里 .a/.so 是同一份产物
        s_dst = static_arch_dirs.get(arch)
        if s_dst:
            static_count = 0
            static_seen = set()
            for src in srcs:
                # 两处候选目录（<outRoot> 与 build_temp）里是同一份 libFAP.a，按文件名去重只拷一次
                for name in sorted(os.listdir(src)) if os.path.isdir(src) else []:
                    if not name.endswith(".a") or name in static_seen:
                        continue
                    static_seen.add(name)
                    try:
                        shutil.copy2(os.path.join(src, name), os.path.join(s_dst, name), follow_symlinks=True)
                        static_count += 1
                    except OSError as exc:
                        print(f"[Linux 静态库] 复制失败: {name} ({exc})")
            if static_count:
                print(f"  [{arch} Linux静态库] {static_count} 个 .a -> {s_dst}")

            # 静态包里 libFAP.a 是静态的，但**算法库仍是独立的 libFAPAlgo.so**：
            # OXiAlgoLoader 运行期 dlopen 它，且只从主库自身目录找；FAPAlgo 又动态依赖
            # opencv_world / onnxruntime。checked-in 的 static/Linux/<arch> 只有 .a + usb/uvc，
            # 于是客户按文档用静态库编完、一跑就加载不到算法库。这里把这三样一并补齐。
            # ⚠️ static 构建目录优先（同名产物在 shared 那次也会产出，但要以静态这次为准）
            static_srcs = ([s for s in srcs if os.sep + "static" + os.sep in s]
                           + [s for s in srcs if os.sep + "static" + os.sep not in s])
            algo_seen = set()
            for src in static_srcs:
                if not os.path.isdir(src):
                    continue
                for name in sorted(os.listdir(src)):
                    if name in algo_seen or "Algo" not in name or not name.endswith(".so"):
                        continue
                    p = os.path.join(src, name)
                    if not os.path.isfile(p):
                        continue
                    algo_seen.add(name)
                    copy_file_safe(p, s_dst)
                if algo_seen:
                    break   # 已从这一份构建拿到算法库，别再掺另一份
            if not algo_seen:
                print(f"  [警告] {arch} Linux 静态包里没有算法库（lib*Algo*.so），"
                      f"静态样例运行期会加载失败")

            s_dep = 0
            for src in static_srcs:
                has_link = (os.path.isfile(os.path.join(src, "build.ninja"))
                            or os.path.isfile(os.path.join(src, "CMakeFiles", "FAPAlgo.dir", "link.txt")))
                if not has_link:
                    continue
                s_dep = copy_linux_runtime_deps(src, s_dst, arch, third_party)
                if s_dep > 0:
                    break
            if s_dep > 0:
                print(f"  [{arch} Linux静态包依赖] {s_dep} 个 so（onnxruntime/opencv）-> {s_dst}")

        if total == 0:
            tried = "  |  ".join(srcs)
            print(f"[警告] {arch} 没有 Linux 构建产物（已找 {len(srcs)} 处：{tried}），包内只有 demo 自带的旧库")
            continue

        # opencv / onnxruntime：构建目录里没有，从链接行/第三方目录拿。
        # 依赖解析要用**真的构建过**的目录（里面才有 build.ninja），
        # shell 侧收集目录（<outRoot>\Linux\<arch>）只放了主库，拿它解析必然空。
        dep_count = 0
        for src in srcs:
            has_link = (os.path.isfile(os.path.join(src, "build.ninja"))
                        or os.path.isfile(os.path.join(src, "CMakeFiles", "FAPAlgo.dir", "link.txt")))
            if not has_link:
                continue
            dep_count = copy_linux_runtime_deps(src, dst, arch, third_party)
            if dep_count > 0:
                break

        has_algo = _has_lib(dst, "Algo", ".so")
        note = "" if has_algo else "（缺算法库 lib*Algo*.so，客户机可能加载失败）"
        print(f"  [{arch} Linux库] {total} 个 so -> {dst}{note}")
        if dep_count > 0:
            print(f"  [{arch} Linux依赖] {dep_count} 个 so（onnxruntime/opencv）-> {dst}")
        else:
            print(f"  [警告] {arch} Linux 依赖缺失（缺 onnxruntime/opencv 运行时库，客户机可能加载失败）")


def copy_doc(src_dir, target_root, keep_latest=False):
    """
    文档复制

    打包时排除 .workbuddy / .git 等工程元数据（见 ignore_doc）。
    """

    if not os.path.isdir(src_dir):
        print(f"[跳过] 文档目录不存在: {src_dir}")
        return

    dst = os.path.join(target_root, "doc")

    if os.path.exists(dst):
        remove_dir(dst)

    safe_mkdir(os.path.dirname(dst))
    shutil.copytree(src_dir, dst, ignore=ignore_doc)

    print(f"[复制文档] {src_dir} -> {dst}")

    if keep_latest:
        docs = glob.glob(os.path.join(dst, "*.docx"))

        if len(docs) > 1:
            docs.sort(key=os.path.getmtime)

            for f in docs[:-1]:
                # 删文档是收尾的锦上添花，不能因为它失败就判整次打包失败（与 ps 一致）
                try:
                    os.remove(f)
                except OSError as exc:
                    print(f"[跳过] 旧文档删除失败，保留原样: {f} ({exc})")
                    continue

                print(f"[删除旧文档] {f}")


# ============================================================
# SDK打包（对应 ps 的 New-SdkPackage）
# ============================================================
def create_package(
    sdk_name,
    sdk_dir,
    win_dir,
    android_dir,
    qt_dir,
    target_root,
    config,
    only_app=False,
    suffix=""
):

    result = parse_cmake_versions(sdk_dir)
    version = result["fap_version"]

    print(f"\n====== {sdk_name} SDK {version} ======")

    if only_app:
        target = os.path.join(target_root, config["prefix"] + version + "App")
    else:
        target = os.path.join(target_root, config["prefix"] + version + suffix)

    if os.path.exists(target):
        remove_dir(target)

    safe_mkdir(target)

    # -------------------------
    # headers
    # -------------------------
    if not only_app:
        keywords = config.get("header_keyword") or []
        header_files = config.get("headers") or []

        if keywords:
            copy_headers_by_keyword(
                sdk_dir, os.path.join(target, "include"), keywords
            )

        elif header_files:
            copy_headers(header_files, os.path.join(target, "include"))

        else:
            print("[跳过] 未配置 header_keyword / headers，include 目录为空")

    # -------------------------
    # windows  （copy_win_lib 控制：库 + simpleWin 源码 + demo 测试案例）
    # -------------------------
    if config.get("copy_win_lib"):
        if not only_app:
            # ⚠️ 顺序不能反：copy_win_source_code 会先删掉目标 simpleWin 整个目录，
            # 库必须等源码树拷完再写进 simpleWin\{libx86,libx64,shared\...}
            copy_win_source_code(win_dir, target)
            copy_win_lib(sdk_dir, config["lib"], target, None)
            # 静态那套（simpleWin/static/lib<arch>）同样来自源码树里的旧文件，必须单独刷新
            copy_win_static_libs(target, sdk_dir, config["lib"])

        copy_win_exe(win_dir, target, sdk_dir)

    else:
        print("[跳过] copy_win_lib=false：不拷贝 Win demo"
              "（库 / simpleWin 源码 / win_X86Demo、win_X64Demo 测试案例）")

    # -------------------------
    # android  （copy_android_lib 控制：库 + simpleAndroid 源码 + apk 测试案例）
    # -------------------------
    if config.get("copy_android_lib"):
        if not only_app:
            # ⚠️ 同上：先拷源码树（会先删目标 simpleAndroid），再往 jniLibs 里补整组 so
            copy_android_source_code(android_dir, target)
            copy_android_lib(sdk_dir, config["lib"], target, None, android_dir)

        copy_android_apk(android_dir, target)

    else:
        print("[跳过] copy_android_lib=false：不拷贝 Android demo"
              "（库 / simpleAndroid 源码 / *.apk 测试案例）")

    # -------------------------
    # Qt simpleLinux  （copy_linux_lib 控制：Qt 源码 + linux/ 预编译库，只拷不构建）
    # -------------------------
    if config.get("copy_linux_lib"):
        if not only_app:
            copy_qt_simple_linux(qt_dir, target)
            # 同一份 *_qt 里的 simpleLinux/{shared,static}/Win/<arch> 也是 checked-in 旧库
            copy_qt_win_libs(target, sdk_dir, config["lib"])
            # demo 自带的 shared/Linux/<arch> 是旧库（只有主库 + usb/uvc），
            # 算法库 / onnx / opencv 必须从构建产物整组补齐，否则客户机加载失败
            copy_linux_build_libs(target, sdk_dir, version, config.get("prefix", ""))

    else:
        print("[跳过] copy_linux_lib=false：不拷贝 simpleLinux"
              "（Qt 源码 + linux/ 下的预编译库）")

    # -------------------------
    # doc
    # -------------------------
    if not only_app:
        if config.get("doc"):
            copy_doc(config["doc"], target, config.get("keep_latest_doc"))

        else:
            print("[跳过] 未配置 doc")

    return target


# ============================================================
# 配置加载
# ============================================================
def load_config(path=None):
    """
    载入机型配置。

    缺省用仓库 config/sdk_config.json —— 与 ps/OXi.ps1 是同一份文件，
    不再有 py 专属的 sdk_config_py.json（两份漂移过，行为对不上）。
    """
    if path is None:
        path = DEFAULT_CONFIG

    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


# ============================================================
# 入口
# ============================================================
def build_parser():
    parser = argparse.ArgumentParser(
        prog="OXi.py",
        description="OXiScan SDK 打包（行为以 ps/OXi.ps1 为准）",
    )
    parser.add_argument(
        "--sdk", "-s", default="GSER", metavar="KEY",
        help="机型键，默认 GSER（如 A910 / MIAXIS / Thales / huantian / GSER）",
    )
    parser.add_argument(
        "--config", "-c", default=None, metavar="FILE",
        help="配置文件，默认 config/sdk_config.json",
    )
    parser.add_argument(
        "--only-app", action="store_true",
        help="只出 App 包（不含源码/库/include）",
    )
    parser.add_argument(
        "--suffix", default="", metavar="TEXT",
        help="包目录追加后缀（此时包目录为 prefix+version+suffix）",
    )
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)

    config_file = args.config or DEFAULT_CONFIG
    if not os.path.isfile(config_file):
        print(f"[ERROR] 配置文件不存在: {config_file}")
        return 1

    with open(config_file, "r", encoding="utf-8") as f:
        cfg_root = json.load(f)

    if args.sdk not in cfg_root:
        print(f"[ERROR] {os.path.basename(config_file)} 中找不到键: {args.sdk}"
              f"（可用: {', '.join(cfg_root.keys())}）")
        return 1

    sdk = dict(cfg_root[args.sdk])

    # 必填字段校验（对应 ps 里会直接 KeyError 的位置）
    for field in REQUIRED_FIELDS:
        if not str(sdk.get(field) or "").strip():
            print(f"[ERROR] {os.path.basename(config_file)}[{args.sdk}] "
                  f"缺少必填字段: {field}")
            return 1

    # 布尔值安全转换（缺字段按 false 处理）
    for flag in FLAG_FIELDS:
        sdk[flag] = bool(sdk.get(flag))

    sdk_dir = str(sdk["sdk_dir"]).rstrip("\\/")

    print(f"====== 打包 {args.sdk} ======")
    print(f"  源码目录 : {sdk_dir}")
    print(f"  输出根目录: {sdk['target_root']}")
    print("  拷贝开关 : copy_win_lib={}  copy_android_lib={}  "
          "copy_linux_lib={}  should_package={}".format(
              str(sdk["copy_win_lib"]).lower(),
              str(sdk["copy_android_lib"]).lower(),
              str(sdk["copy_linux_lib"]).lower(),
              str(sdk["should_package"]).lower(),
          ))
    if not sdk["should_package"]:
        print("  [提示] should_package=false：构建流程不会自动调用打包；"
              "当前是手动直接调用，继续出包。")

    target = create_package(
        sdk_name=sdk["name"],
        sdk_dir=sdk_dir,
        win_dir=sdk_dir + "_win",
        android_dir=sdk_dir + "_Android",
        qt_dir=sdk_dir + "_qt",
        target_root=sdk["target_root"],
        config=sdk,
        only_app=args.only_app,
        suffix=args.suffix,
    )

    # ============================================================
    # 结果清单（对应 ps 的 Get-ChildItem 列表）
    # ============================================================
    print(f"\n[完成] {target}")
    print("包内容:")
    for name in sorted(os.listdir(target)):
        kind = "[DIR ]" if os.path.isdir(os.path.join(target, name)) else "[FILE]"
        print(f"  {kind} {name}")
    print(f"输出目录: {target}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
