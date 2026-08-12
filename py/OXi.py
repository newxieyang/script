#!/usr/bin/python
# encoding:utf-8

import os
import shutil
import glob
import json

from utils.fileUtils import (safe_mkdir, remove_dir, parse_cmake_versions)
from utils.copyUtils import (
    copy_android_apk,
    copy_android_source_code,
    copy_win_exe,
    copy_win_source_code,
)

from genSDKAPI import findFilePathNameByKeyWord


# ============================================================
# 公共函数
# ============================================================


def copy_headers(src_files, target_dir):
    """
    通用头文件复制
    """
    safe_mkdir(target_dir)

    for src in src_files:
        if not os.path.exists(src):
            print(f"[跳过] 文件不存在: {src}")
            continue

        shutil.copy2(src, target_dir)
        print(f"[复制头文件] {src}")


def copy_headers_by_keyword(src_dir, target_dir, keywords):
    """
    根据关键字搜索头文件
    """
    if os.path.exists(target_dir):
        remove_dir(target_dir)

    safe_mkdir(target_dir)

    for key in keywords:
        fp = findFilePathNameByKeyWord(src_dir, key)

        if fp:
            shutil.copy2(fp, target_dir)
            print(f"[复制头文件] {fp}")
        else:
            print(f"[未找到] {key}")


def copy_win_lib(src_dir, lib_name, target_dir, headers=None):
    """
    Windows库复制
    """

    safe_mkdir(target_dir)

    # headers
    if headers:
        copy_headers(headers, target_dir)

    # x86
    x86_src = os.path.join(
        src_dir, "cmake-build-release-vs2019_x86", "libFAP", "Release"
    )

    lib_x86 = os.path.join(target_dir, "libx86")

    dll_x86 = os.path.join(target_dir, "Release")

    safe_mkdir(lib_x86)
    safe_mkdir(dll_x86)

    shutil.copy2(os.path.join(x86_src, lib_name + ".lib"), lib_x86)

    shutil.copy2(os.path.join(x86_src, lib_name + ".dll"), dll_x86)

    # x64
    x64_src = os.path.join(
        src_dir, "cmake-build-release-vs2019_x64", "libFAP", "Release"
    )

    lib_x64 = os.path.join(target_dir, "libx64")

    dll_x64 = os.path.join(target_dir, "x64", "Release")

    safe_mkdir(lib_x64)
    safe_mkdir(dll_x64)

    shutil.copy2(os.path.join(x64_src, lib_name + ".lib"), lib_x64)

    shutil.copy2(os.path.join(x64_src, lib_name + ".dll"), dll_x64)


def copy_android_lib(src_dir, lib_name, target_dir, headers=None):
    """
    Android库复制
    """

    include_dir = os.path.join(target_dir, "include")

    safe_mkdir(include_dir)

    if headers:
        copy_headers(headers, include_dir)

    v7_dir = os.path.join(target_dir, "armeabi-v7a")
    v8_dir = os.path.join(target_dir, "arm64-v8a")

    safe_mkdir(v7_dir)
    safe_mkdir(v8_dir)

    shutil.copy2(
        os.path.join(
            src_dir,
            "cmake-build-release-armeabi-v7a",
            "libFAP",
            "lib" + lib_name + ".so",
        ),
        v7_dir,
    )

    shutil.copy2(
        os.path.join(
            src_dir, "cmake-build-release-arm64-v8a", "libFAP", "lib" + lib_name + ".so"
        ),
        v8_dir,
    )


def copy_doc(src_dir, target_root, keep_latest=False):
    """
    文档复制
    """

    dst = os.path.join(target_root, "doc")

    if os.path.exists(dst):
        remove_dir(dst)

    shutil.copytree(src_dir, dst)

    print(f"[复制文档] {src_dir} -> {dst}")

    if keep_latest:
        docs = glob.glob(os.path.join(dst, "*.docx"))

        if len(docs) > 1:
            docs.sort(key=os.path.getmtime)

            for f in docs[:-1]:
                os.remove(f)

                print(f"[删除旧文档] {f}")


# ============================================================
# SDK打包
# ============================================================
def create_package(sdk_name, sdk_dir, win_dir, android_dir, target_root, config, onlyApp):

    result = parse_cmake_versions(sdk_dir)
    version = result["fap_version"]

    print(f"\n====== {sdk_name} SDK {version} ======")

    # suffix = "dy"
    # if result.get("build_static"):
    #     suffix = "Static"
    suffix=""

    if onlyApp:
        target = os.path.join(target_root, config["prefix"] + version + "App")
    else:
        target = os.path.join(target_root, config["prefix"] + version + suffix)

    if os.path.exists(target):
        remove_dir(target)

    safe_mkdir(target)

    # -------------------------
    # headers
    # -------------------------
    if not onlyApp:
        if config.get("header_keyword"):
            copy_headers_by_keyword(
                sdk_dir, os.path.join(target, "include"), config["header_keyword"]
            )

        elif config.get("headers"):
            copy_headers(config["headers"], os.path.join(target, "include"))

    # -------------------------
    # windows
    # -------------------------
    if not onlyApp:
        if config.get("copy_win_lib"):
            copy_win_lib(sdk_dir, config["lib"], target, None)

        copy_win_source_code(win_dir, target)
    copy_win_exe(win_dir, target)

    # -------------------------
    # android
    # -------------------------
    if not onlyApp:
        if config.get("copy_android_lib"):
            copy_android_lib(sdk_dir, config["lib"], target, None)

        copy_android_source_code(android_dir, target)

    copy_android_apk(android_dir, target)

    # -------------------------
    # doc
    # -------------------------
    if not onlyApp:
        if config.get("doc"):
            copy_doc(config["doc"], target, config.get("keep_latest_doc"))

        print(f"\n✅ 完成:{target}")

    return target


def load_config(path=None):
    base_dir = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base_dir, "sdk_config.json")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


# ============================================================
# 配置入口
# ============================================================


if __name__ == "__main__":
    config = load_config()
    # config["GSER","A910", "MIAXIS", "huantian", "Thales",]
    sdk = config["A910"]
    OnlyApp = True

    create_package(
        sdk_name=sdk["name"],
        sdk_dir=sdk["sdk_dir"],
        win_dir=sdk["sdk_dir"] + "_win",
        android_dir=sdk["sdk_dir"] + "_Android",
        target_root=sdk["target_root"],
        config=sdk,
        onlyApp=OnlyApp,
    )
