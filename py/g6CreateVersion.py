#!/usr/bin/python
# encoding:utf-8
import shutil
import os
from genSDKAPI import findFilePathNameByKeyWord
from utils.fileUtils import safe_mkdir, remove_dir, parse_cmake_versions
from utils.copyUtils import copy_android_source_code, copy_win_exe, copy_android_apk, copy_win_source_code


def copy_win_lib(src_dir: str, lib_name: str, target_dir: str, cus: str):
    """复制Windows头文件、x86/x64 lib/dll"""
    inc_src = os.path.join(src_dir, "libFAP", "include")
    header_names = [f"{cus}ScanAPI.h", f"{cus}ScanUltimate.h", f"{cus}ScanUltimateApi_err.h"]
    for h in header_names:
        shutil.copy2(os.path.join(inc_src, h), target_dir)

    # x86
    x86_lib_src = os.path.join(src_dir, "cmake-build-release-vs2019_x86", "libFAP", "Release")
    safe_mkdir(os.path.join(target_dir, "libx86"))
    safe_mkdir(os.path.join(target_dir, "Release"))
    shutil.copy2(os.path.join(x86_lib_src, f"{lib_name}.lib"), os.path.join(target_dir, "libx86"))
    shutil.copy2(os.path.join(x86_lib_src, f"{lib_name}.dll"), os.path.join(target_dir, "Release"))

    # x64
    x64_lib_src = os.path.join(src_dir, "cmake-build-release-vs2019_x64", "libFAP", "Release")
    safe_mkdir(os.path.join(target_dir, "libx64"))
    safe_mkdir(os.path.join(target_dir, "x64", "Release"))
    shutil.copy2(os.path.join(x64_lib_src, f"{lib_name}.lib"), os.path.join(target_dir, "libx64"))
    shutil.copy2(os.path.join(x64_lib_src, f"{lib_name}.dll"), os.path.join(target_dir, "x64", "Release"))


def copy_android_lib(src_dir: str, lib_name: str, target_dir: str, cus: str):
    """复制Android头文件、v7a/v8a so库"""
    tg_inc = os.path.join(target_dir, "include")
    safe_mkdir(tg_inc)
    inc_src = os.path.join(src_dir, "libFAP", "include")
    header_names = [f"{cus}ScanAPI.h", f"{cus}ScanUltimate.h", f"{cus}ScanUltimateApi_err.h"]
    for h in header_names:
        shutil.copy2(os.path.join(inc_src, h), tg_inc)

    abi_v7 = os.path.join(target_dir, "armeabi-v7a")
    abi_v8 = os.path.join(target_dir, "arm64-v8a")
    safe_mkdir(abi_v7)
    safe_mkdir(abi_v8)
    shutil.copy2(os.path.join(src_dir, "cmake-build-release-armeabi-v7a", "libFAP", f"lib{lib_name}.so"), abi_v7)
    shutil.copy2(os.path.join(src_dir, "cmake-build-release-arm64-v8a", "libFAP", f"lib{lib_name}.so"), abi_v8)


def copy_doc(src_doc_dir: str, target_root: str):
    dst_doc = os.path.join(target_root, "doc")
    if os.path.exists(dst_doc):
        remove_dir(dst_doc)
    shutil.copytree(src_doc_dir, dst_doc)
    print(f"[复制文档] {src_doc_dir} -> {dst_doc}")


def copy_header_by_keyword(src_dir: str, target_dir: str):
    tg_header = os.path.join(target_dir, "include")
    if os.path.exists(tg_header):
        remove_dir(tg_header)
    safe_mkdir(tg_header)
    keywords = ["ScanAPI.h", "ScanUltimate.h", "ScanUltimateApi_err.h"]
    for kw in keywords:
        fp = findFilePathNameByKeyWord(src_dir, kw)
        shutil.copy2(fp, tg_header)



def create_version_package(
    sdk_dir: str,
    win_src: str,
    android_src: str,
    target_root: str
):

    safe_mkdir(target_root)

    # 读取版本
    cmake_info = parse_cmake_versions(sdk_dir)
    sdk_ver = cmake_info["fap_version"]
    print(f"\n===== SDK版本号: {sdk_ver} =====")

    # 最终输出目录
    final_target = os.path.join(target_root, f"G6SDKv{sdk_ver}")
    safe_mkdir(final_target)
    print(f"[打包输出目录] {final_target}")

    # 复制公共头文件
    print("\n1. 复制通用头文件")
    copy_header_by_keyword(sdk_dir, final_target)

    # Windows产物
    print("\n2. 复制Windows Demo程序")
    copy_win_exe(win_src, final_target)
    print("\n3. 复制Windows源码工程")
    copy_win_source_code(win_src, final_target)

    # Android产物
    print("\n4. 复制Android源码工程")
    copy_android_source_code(android_src, final_target)
    print("\n5. 复制Android APK安装包")
    copy_android_apk(android_src, final_target)

    print(f"\n✅ SDK打包完成: {final_target}")
    return final_target


if __name__ == '__main__':
    # 仅配置常量、拼接路径，无任何拷贝业务逻辑
    CUSTOM_LIST = ["A910", "MIAXIS", "huantian", "Thales", "mantra"]
    INDEX = 0
    CUSTOM_STR = CUSTOM_LIST[INDEX]
    LIB_NAME = "FAP60"

    BASE_SOURCE = r"D:\git\oxi\g6"
    BASE_TARGET = r"D:\G6SDKLib"

    SDK_DIR = os.path.join(BASE_SOURCE, f"{CUSTOM_STR}", f"{CUSTOM_STR}")
    target_root = os.path.join(BASE_TARGET, CUSTOM_STR)
    safe_mkdir(target_root)

    win_source_path = os.path.join(BASE_SOURCE, f"{CUSTOM_STR}", f"{CUSTOM_STR}_win")
    android_source_path = os.path.join(BASE_SOURCE, f"{CUSTOM_STR}", f"{CUSTOM_STR}_Android")

    create_version_package(
        sdk_dir=SDK_DIR,
        win_src=win_source_path,
        android_src=android_source_path,
        target_root=target_root
    )