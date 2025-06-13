# !/usr/bin/python
# encoding:utf-8

import os

def is_hidden(path):
    """判断路径是否为隐藏文件或目录"""
    basename = os.path.basename(path)
    return basename.startswith('.') or (os.name == 'nt' and basename.startswith('$') or basename.startswith('cmake') or basename.startswith('src'))
 

def findFilePathNameByKeyWord(pjDir, key):
    for root, dirs, files in os.walk(pjDir):
    # 忽略隐藏目录
        dirs[:] = [d for d in dirs if not is_hidden(d)]
        for file in files:
            # print(f"File: {os.path.join(root, file)}")
            if key in file:
                return os.path.join(root, file)
            

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