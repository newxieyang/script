# !/usr/bin/python
# encoding:utf-8

import os
import re
import shutil
import chardet

def is_hidden(path):
    """
    判断路径是否为隐藏文件或目录。

    与 ps/fileUtils.ps1 的 Test-IsHiddenName 逐条对齐：. / $ / cmake / src 开头的目录
    一律剪枝（cmake 是为了避开 cmake-build*，src 是为了避开 src 源码聚合目录）。

    注意原来写成 `a or (nt and b or c or d)`：Python 里 and 优先级高于 or，
    实际等价于 `a or (nt and b) or c or d`，$ 开头的判断被 nt 短路了。
    """
    basename = os.path.basename(path)
    return (basename.startswith('.')
            or basename.startswith('$')
            or basename.startswith('cmake')
            or basename.startswith('src'))


def findFilePathNameByKeyWord(pjDir, key):
    """按文件名关键字深度优先找第一个命中（与 ps 的 Find-FilePathByKeyword 一致，大小写敏感）"""
    if not os.path.isdir(pjDir):
        return None

    for root, dirs, files in os.walk(pjDir):
        # 忽略隐藏目录（任意一层祖先命中即整棵剪掉）
        dirs[:] = [d for d in dirs if not is_hidden(d)]
        for file in files:
            if key in file:
                return os.path.join(root, file)

    return None

def readVer(pjDir):
    verPN = findFilePathNameByKeyWord(pjDir, "ersion")
    if verPN == "":
        print("verPN is null")
        return ""
    f = open(file=verPN, encoding="utf-8")
    verName = ""
    for line in f:
        if "VERSION_MAJOR" in line:
            verName += line.split(" ")[2].replace('\n', '') + "."
        if "VERSION_MINOR" in line:
            verName += line.split(" ")[2].replace('\n', '') + "."
        if "VERSION_PATCH" in line:
            verName += line.split(" ")[2].replace('\n', '') + "."
        if "VERSION_BUILD" in line:
            verName += line.split(" ")[2].replace('\n', '')
            break

    print(verName)
    return verName


def readCmakeVer(pjDir):
    # verPN = findFilePathNameByKeyWord(pjDir, "ersion")
  
    f = open(file=(pjDir +"CMakeLists.txt"), encoding="utf-8")
    verName = ""
    for line in f:
        if "set(FAP_VERSION_MAJOR" in line:
            verName += line.split(" ")[1].replace(')', '').replace('\n', '') + "."
        if "set(FAP_VERSION_MINOR" in line:
            verName += line.split(" ")[1].replace(')', '').replace('\n', '') + "."
        if "set(FAP_VERSION_PATCH" in line:
            verName += line.split(" ")[1].replace(')', '').replace('\n', '') + "."
        if "set(FAP_VERSION_BUILD" in line:
            verName += line.split(" ")[1].replace(')', '').replace('\n', '')
            break

    print(verName)
    return verName


def readAlgoVer(pjDir):
    # verPN = findFilePathNameByKeyWord(pjDir, "ersion")
  
    f = open(file=(pjDir +"CMakeLists.txt"), encoding="utf-8")
    verName = ""
    for line in f:
        if "set(OXiAlgVer" in line:
            verName += line.split(" ")[1].replace(')', '').replace('\n', '')
            break

    print(verName)
    return verName

# algorithm_version fap_version is_include_alg
# 使用 -> 定义返回类型，使用 : 定义参数类型
def parse_cmake_versions(pjDir):
    file_path = os.path.join(pjDir, "version.cmake")
    with open(file_path , 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. 提取各个变量的值
    # 匹配模式：set(变量名 值)
    def get_var(var_name):
        pattern = rf'set\s*\(\s*{var_name}\s+([^)\s]+)\s*\)'
        match = re.search(pattern, content)
        return match.group(1) if match else None

    alg_ver = get_var("OXiAlgVer")
    fap_major = get_var("FAP_VERSION_MAJOR")
    fap_minor = get_var("FAP_VERSION_MINOR")
    fap_patch = get_var("FAP_VERSION_PATCH")
    fap_build = get_var("FAP_VERSION_BUILD")
    build_static = "OFF"

    # 2. 拼接 FAP 版本号
    fap_full_version = f"{fap_major}.{fap_minor}.{fap_patch}.{fap_build}"

    # 3. 处理“双数带算法”逻辑
    # 转换为整数判断奇偶
    try:
        build_num = int(fap_build)
        is_even = (build_num % 2 == 0)
    except (ValueError, TypeError):
        is_even = False

    # 最终输出逻辑
    final_output = fap_full_version
    if is_even and alg_ver:
        final_output += f" (Alg: {alg_ver})"

    return {
        "algorithm_version": alg_ver,
        "fap_version": fap_full_version,
        "is_include_alg": is_even,
        "build_static":build_static.lower()=="on",
        "final_string": final_output

    }


def safe_mkdir(path: str):
    """
    不存在则创建文件夹（含中间目录）。

    对应 ps 的 New-SafeDirectory：那边用 New-Item -ItemType Directory -Force，
    会自动补齐中间层。原来这里用 os.mkdir（单层），target_root 还不存在时
    直接抛 FileNotFoundError —— 早先能跑通只是因为碰巧 target_root 已被建过。
    """
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)
        print(f"[创建目录] {path}")


def remove_dir(dir_path: str):
    """安全递归删除目录，优先删除内部文件再删文件夹"""
    if not os.path.exists(dir_path):
        return
    try:
        # 优先使用shutil.rmtree，极简可靠
        shutil.rmtree(dir_path)
        print(f"[删除目录] {dir_path}")
    except Exception:
        # 兜底方案：逐层删除
        for root, dirs, files in os.walk(dir_path, topdown=False):
            for file in files:
                os.remove(os.path.join(root, file))
            for d in dirs:
                os.rmdir(os.path.join(root, d))
        try:
            os.removedirs(dir_path)
        except OSError as e:
            print(f"[删除警告] {dir_path} 清理不完全: {e}")


def get_file_encoding(file_path: str) -> str:
    """自动检测文件编码"""
    with open(file_path, "rb") as f:
        raw = f.read()
    return chardet.detect(raw)["encoding"] or "utf-8"



def copy_files_by_suffix(src_root: str, dst_dir: str, suffix_list: list[str]):
    """通用：遍历目录复制指定后缀文件到目标文件夹"""
    if not os.path.isdir(src_root):
        print(f"[跳过] 源目录不存在: {src_root}")
        return
    safe_mkdir(dst_dir)

    for root, _, files in os.walk(src_root):
        for fname in files:
            if any(fname.endswith(suf) for suf in suffix_list):
                src_path = os.path.join(root, fname)
                shutil.copy2(src_path, dst_dir)
                print(f"  复制: {fname}")
