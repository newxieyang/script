#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import shutil
from pathlib import Path

# ====================== 配置区 ======================

custom_list = ["A910", "MIAXIS",  "huantian",  "Thales",  "mantra"]
libName_default = "FAP60"

sourceDir = r"D:\\git\\oxi\\g6\\"

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
    SDKDir      = Path(sourceDir) / {customStr} / f"{customStr}v66"
    androidDir  = Path(sourceDir) / {customStr} / f"{customStr}_Android"
    winDir      = Path(sourceDir) / {customStr} / f"{customStr}_win"

  

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

    vs64Dir = SDKDir / "cmake-build-release-vs2019_x64"  / "Release"
    vs86Dir = SDKDir / "cmake-build-release-vs2019_x86"  / "Release"

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
    print(vs64Dir / f"{libName}.lib")
    # 复制 x64
    shutil.copy2(vs64Dir / f"{libName}.lib", winDir / "libx64")
    shutil.copy2(vs64Dir / f"{libName}.dll", winDir / "x64" / "Release")

    print("Windows 版本复制完成")


def copy_android(SDKDir: Path, androidDir: Path, libName: str, customIndex: int):
    print("正在复制 Android 版本...")


    androidv7Dir = SDKDir / "cmake-build-release-armeabi-v7a" 
    androidv8Dir = SDKDir / "cmake-build-release-arm64-v8a"

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