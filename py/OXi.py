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
    copy_qt_linux_libs,
    copy_win_exe,
    copy_win_source_code,
    find_qt_linux_lib_dir,
    ignore_doc,
    make_pack_ignore,
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
    Windows库复制（对应 ps 的 Copy-WinLib）
    """

    safe_mkdir(target_dir)

    # headers
    if headers:
        copy_headers(headers, target_dir)

    # x86: lib -> libx86, dll -> Release
    x86_src = os.path.join(
        src_dir, "cmake-build-release-vs2019_x86", "libFAP", "Release"
    )
    # x64: lib -> libx64, dll -> x64\Release
    x64_src = os.path.join(
        src_dir, "cmake-build-release-vs2019_x64", "libFAP", "Release"
    )
    if not os.path.isdir(x86_src) and not os.path.isdir(x64_src):
        # 本机各机型都属这种形态（库由构建流程产出，不在这两个 cmake-build 目录里），
        # 给一行提示即可，不必逐个文件刷 4 条 [跳过]
        print(
            f"[跳过] Win 库源目录不存在: "
            f"{src_dir}\\cmake-build-release-vs2019_{{x86,x64}}\\libFAP\\Release"
        )
        return

    copy_file_safe(os.path.join(x86_src, lib_name + ".lib"),
                   os.path.join(target_dir, "libx86"))
    copy_file_safe(os.path.join(x86_src, lib_name + ".dll"),
                   os.path.join(target_dir, "Release"))

    copy_file_safe(os.path.join(x64_src, lib_name + ".lib"),
                   os.path.join(target_dir, "libx64"))
    copy_file_safe(os.path.join(x64_src, lib_name + ".dll"),
                   os.path.join(target_dir, "x64", "Release"))


def copy_android_lib(src_dir, lib_name, target_dir, headers=None):
    """
    Android库复制（对应 ps 的 Copy-AndroidLib）
    """

    include_dir = os.path.join(target_dir, "include")

    safe_mkdir(include_dir)

    if headers:
        copy_headers(headers, include_dir)

    so_name = "lib" + lib_name + ".so"
    v7_src = os.path.join(src_dir, "cmake-build-release-armeabi-v7a", "libFAP", so_name)
    v8_src = os.path.join(src_dir, "cmake-build-release-arm64-v8a", "libFAP", so_name)
    if not os.path.isfile(v7_src) and not os.path.isfile(v8_src):
        print(
            f"[跳过] Android 库源目录不存在: "
            f"{src_dir}\\cmake-build-release-{{arm64-v8a,armeabi-v7a}}\\libFAP\\{so_name}"
        )
        return

    copy_file_safe(v7_src, os.path.join(target_dir, "armeabi-v7a"))
    copy_file_safe(v8_src, os.path.join(target_dir, "arm64-v8a"))


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
                os.remove(f)

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
            copy_win_lib(sdk_dir, config["lib"], target, None)
            copy_win_source_code(win_dir, target)

        copy_win_exe(win_dir, target)

    else:
        print("[跳过] copy_win_lib=false：不拷贝 Win demo"
              "（库 / simpleWin 源码 / win_X86Demo、win_X64Demo 测试案例）")

    # -------------------------
    # android  （copy_android_lib 控制：库 + simpleAndroid 源码 + apk 测试案例）
    # -------------------------
    if config.get("copy_android_lib"):
        if not only_app:
            copy_android_lib(sdk_dir, config["lib"], target, None)
            copy_android_source_code(android_dir, target)

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
