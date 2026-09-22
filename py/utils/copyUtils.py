#!/usr/bin/python
# encoding:utf-8
import os
import shutil

from utils.fileUtils import copy_files_by_suffix, remove_dir

def copy_win_exe(src_dir: str, tg_root: str):
    """复制Windows x86/x64 exe dll"""
    # x86
    src_x86 = os.path.join(src_dir, "Release")
    dst_x86 = os.path.join(tg_root, "win_X86Demo")
    copy_files_by_suffix(src_x86, dst_x86, [".exe", ".dll"])

    # x64
    src_x64 = os.path.join(src_dir, "x64", "Release")
    dst_x64 = os.path.join(tg_root, "win_X64Demo")
    copy_files_by_suffix(src_x64, dst_x64, [".exe", ".dll"])


def copy_android_apk(src_dir: str, target_dir: str):
    """复制Android debug APK"""
    src_apk_root = os.path.join(src_dir, "app", "build", "outputs", "apk", "debug")
    copy_files_by_suffix(src_apk_root, target_dir, [".apk"])


def ignore_win_code(src_dir, names):
    ignore_list = ["Release", "x64", ".vs", ".git"]
    return [n for n in names if os.path.isdir(os.path.join(src_dir, n)) and n in ignore_list]


def copy_win_source_code(src_dir: str, target_root: str):
    dst_code = os.path.join(target_root, "simpleWin")
    if os.path.exists(dst_code):
        remove_dir(dst_code)
    shutil.copytree(src_dir, dst_code, ignore=ignore_win_code)
    print(f"[复制Windows源码] {src_dir} -> {dst_code}")


def ignore_android_code(src_dir, names):
    ignore_list = [".gradle", ".git", ".idea", "build", ".cxx"]
    return [n for n in names if os.path.isdir(os.path.join(src_dir, n)) and n in ignore_list]


def copy_android_source_code(src_dir: str, target_root: str):
    dst_code = os.path.join(target_root,  "simpleAndroid")
    shutil.copytree(src_dir, dst_code, ignore=ignore_android_code)
    print(f"[复制Android源码] {src_dir} -> {dst_code}")