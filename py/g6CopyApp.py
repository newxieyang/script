#!/usr/bin/python
# encoding:utf-8
import shutil
import os


from utils.fileUtils import parse_cmake_versions, safe_mkdir
from utils.copyUtils import copy_win_exe, copy_android_apk



def create_version_package(
    sdk_source_dir: str,
    win_source: str,
    android_source: str,
    target_root: str
):

    safe_mkdir(target_root)

    # 读取CMake版本
    cmake_info = parse_cmake_versions(sdk_source_dir)
    sdk_ver = cmake_info["fap_version"]
    print(f"\n[SDK版本号] {sdk_ver}")

    # 最终打包目录
    final_target = os.path.join(target_root, f"G6Appv{sdk_ver}")
    safe_mkdir(final_target)
    print(f"\n[输出根目录] {final_target}")

    # 统一复制逻辑全部内置在此函数
    print("\n===== 开始复制Windows程序 =====")
    copy_win_exe(win_source, final_target)

    print("\n===== 开始复制Android APK =====")
    copy_android_apk(android_source, final_target)

    print(f"\n✅ 打包完成，输出路径: {final_target}")
    return final_target


if __name__ == '__main__':
    # 仅配置常量 + 拼接路径，无业务复制逻辑
    CUSTOM_LIST = ["A910", "MIAXIS", "huantian", "Thales", "mantra"]
    INDEX = 0
    CUSTOM_STR = CUSTOM_LIST[INDEX]

    BASE_SOURCE = r"D:\git\oxi\g6"
    BASE_TARGET_ROOT = r"D:\G6SDKLib"

    # 拼接各类路径
    SDK_SOURCE_DIR = os.path.join(BASE_SOURCE, CUSTOM_STR, CUSTOM_STR)
    target_root = os.path.join(BASE_TARGET_ROOT, CUSTOM_STR)
    safe_mkdir(target_root)

    win_source = f"{SDK_SOURCE_DIR}_win"
    android_source = f"{SDK_SOURCE_DIR}_Android"

    # 仅调用打包函数，复制逻辑全部在函数内部
    create_version_package(
        sdk_source_dir=SDK_SOURCE_DIR,
        win_source=win_source,
        android_source=android_source,
        target_root=target_root
    )