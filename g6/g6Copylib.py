#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import shutil
from pathlib import Path

# ====================== 配置区 ======================
custom_list = [
    "A910",      # 0
    "MIAXIS",    # 1
    "win7",      # 2
    "fangzheng", # 3
    "new",       # 4
    "kejin",     # 5
    "yinken",    # 6
    "huantian",  # 7
    "Thales",    # 8
    "shenzhou"   # 9
]

libName_default = "FAP60"

sourceDir = r"D:\git\oxi\g6"

# ====================== 主函数 ======================
def main():
    if len(sys.argv) < 2:
        print("用法:")
        print("  python build_copy.py <customIndex> [platformIndex]")
        print("\n当前支持的 custom:")
        for i, name in enumerate(custom_list):
            print(f"  {i} → {name}")
        input("\n按任意键退出...")
        return

    customIndex = int(sys.argv[1])
    platformIndex = int(sys.argv[2]) if len(sys.argv) > 2 else None

    if customIndex < 0 or customIndex >= len(custom_list):
        print(f"错误：customIndex {customIndex} 超出范围 (0~9)")
        return

    customStr = custom_list[customIndex]
    libName = "AraDevice" if customIndex == 0 else libName_default

    print(f"正在生成 custom = {customStr} | libName = {libName}")

    # 路径定义
    SDKDir      = Path(sourceDir) / f"FAP6010_{customStr}"
    androidDir  = Path(sourceDir) / f"G6010Android_{customStr}"
    winDir      = Path(sourceDir) / f"g6010WinDemo_{customStr}"

    if customIndex == 0:
        SDKDir = Path(sourceDir) / f"{customStr}"
        androidDir  = Path(sourceDir) / f"G6010Android_ARATEK"
        winDir      = Path(sourceDir) / f"g6010WinDemo_ARATEK"

    # 根据 customIndex 特殊处理 winDir
    if customIndex == 4:
        winDir = Path(sourceDir) / f"g6MFC_{customStr}"

    # ====================== 执行复制 ======================
    if platformIndex is None or platformIndex == 0:
        copy_win(SDKDir, winDir, libName, customIndex)
        copy_android(SDKDir, androidDir, libName, customIndex)

    elif platformIndex == 1:
        copy_win(SDKDir, winDir, libName, customIndex)

    elif platformIndex == 2:
        copy_android(SDKDir, androidDir, libName, customIndex)

    else:
        print(f"未知的 platformIndex: {platformIndex}")

    print("复制完成！")


def copy_win(SDKDir: Path, winDir: Path, libName: str, customIndex: int):
    print("正在复制 Windows 版本...")

    vs64Dir = SDKDir / "cmake-build-release-vs2019_x64" / "libFAP" / "Release"
    vs86Dir = SDKDir / "cmake-build-release-vs2019_x86" / "libFAP" / "Release"

    # 复制头文件（根据是否存在不同文件）
    header_files = [
        ("ScanAPI.h", "OXiScanAPI.h"),
        ("ScanUltimateApi_err.h", "OXiScanUltimateApi_err.h"),
        ("ScanUltimate.h", "OXiScanUltimate.h")
    ]

    for src_name, alt_name in header_files:
        src_path = SDKDir / "libFAP" / "include" / src_name
        if src_path.exists():
            shutil.copy2(src_path, winDir)
            print(f"已复制 {src_name}")
        else:
            alt_path = SDKDir / "libFAP" / "include" / alt_name
            if alt_path.exists():
                shutil.copy2(alt_path, winDir)
                print(f"已复制 {alt_name}")
            else:
                print(f"警告：未找到 {src_name} 或 {alt_name}")

    print(vs86Dir / f"{libName}.lib")
    print( winDir / "libx86")
    # 复制 x86
    shutil.copy2(vs86Dir / f"{libName}.lib", winDir / "libx86")
    shutil.copy2(vs86Dir / f"{libName}.dll", winDir / "Release")

    # 复制 x64
    shutil.copy2(vs64Dir / f"{libName}.lib", winDir / "libx64")
    shutil.copy2(vs64Dir / f"{libName}.dll", winDir / "x64" / "Release")

    print("Windows 版本复制完成")


def copy_android(SDKDir: Path, androidDir: Path, libName: str, customIndex: int):
    print("正在复制 Android 版本...")

    if customIndex == 0:
        androidv7Dir = SDKDir / "cmake-build-release-arm7-r18" / "libFAP"
        androidv8Dir = SDKDir / "cmake-build-release-arm8-r18" / "libFAP"
    else:
        androidv7Dir = SDKDir / "cmake-build-release-armeabi-v7a" / "libFAP"
        androidv8Dir = SDKDir / "cmake-build-release-arm64-v8a" / "libFAP"

    jniDir = androidDir / "libFAP" / "src" / "main" / "cpp"

    # 复制 .so 文件
    shutil.copy2(androidv7Dir / f"lib{libName}.so", jniDir / "armeabi-v7a")
    shutil.copy2(androidv8Dir / f"lib{libName}.so", jniDir / "arm64-v8a")

    # 复制头文件（同 Windows 逻辑）
    header_files = [
        ("ScanAPI.h", "OXiScanAPI.h"),
        ("ScanUltimateApi_err.h", "OXiScanUltimateApi_err.h"),
        ("ScanUltimate.h", "OXiScanUltimate.h")
    ]

    for src_name, alt_name in header_files:
        src_path = SDKDir / "libFAP" / "include" / src_name
        if src_path.exists():
            shutil.copy2(src_path, jniDir / "include")
        else:
            alt_path = SDKDir / "libFAP" / "include" / alt_name
            if alt_path.exists():
                shutil.copy2(alt_path, jniDir / "include")

    print("Android 版本复制完成")


if __name__ == "__main__":
    main()