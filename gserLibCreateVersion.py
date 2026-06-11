# !/usr/bin/python
# encoding:utf-8

import shutil
import os
import chardet
import glob
from utils.fileUtils import *


def removeDir(dir_path):
    for root, dirs, files in os.walk(dir_path, topdown=False):
        for file in files:
            os.remove(os.path.join(root, file))
        for dir in dirs:
            os.rmdir(os.path.join(root, dir))
 
    # 现在可以尝试删除空目录
    try:
        os.removedirs(dir_path)
    except OSError as e:
        print(e)





def copyWin(srcDir, tgDir, is_include_alg):
    # def traverse_directory(exe86Src):
    for root, dirs, files in os.walk(srcDir):
        for file in files:
            if file.endswith(".exe"):
                shutil.copy2(os.path.join(root, file), tgDir)
            if file.endswith(".dll"):
                if  "FAP" in file:
                    shutil.copy2(os.path.join(root, file), tgDir)
                else:
                    if  is_include_alg:
                        shutil.copy2(os.path.join(root, file), tgDir)

def copyWinExe(srcDir, tgDir, is_include_alg):
    #copy x86
    exe86Src = srcDir + "/Release/"
    print(exe86Src)
    tgx86 = tgDir + "/winx86Demo"
    if not os.path.isdir(tgx86):
        os.mkdir(tgx86)

    copyWin(exe86Src, tgx86, is_include_alg)

    exe64Src = srcDir +  "/x64/Release/"
    tgx64 = tgDir + "/winx64Demo"
    if not os.path.isdir(tgx64):
        os.mkdir(tgx64)

    copyWin(exe64Src, tgx64, is_include_alg)



def ignore_predicate(src_dir, names):
    # 定义需要忽略的文件夹名列表
    ignore_folders = ['Release', 'x64', '.vs', '.git']
    ignored_names = []
    for name in names:
        full_path = os.path.join(src_dir, name)
        if os.path.isdir(full_path) and name in ignore_folders:
            ignored_names.append(name)
    return ignored_names





def copyAndroidAPK(srcDir, target):
    srouceDir = srcDir + "/app/build/outputs/apk/"
    tgDir = target + "/Andoird"
    for root, dirs, files in os.walk(srouceDir):
        for file in files:
            if file.endswith(".apk"):
                shutil.copy2(os.path.join(root, file), tgDir)

if __name__ == '__main__':
  
    sourceDir = "D:/git/oxi/OXiScan/"
    
    libName = "FAP"
    SDKJ = "OXi_FP_"
   
    print(sourceDir)

    result = parse_cmake_versions(sourceDir)
    # SDKver = readCmakeVer(sourceDir)
    print("SDKver:" + result['fap_version'] + ";")

    # MKver = readMkVer(SDKDir, customStr)
    # print("MKver:" + MKver + ";")
    docSrc = "D:/GSerSDKLib/doc"

    subfix = "Static" if result.get('build_static') else ""

    targetDir = "D:/GSerSDKLib/"+SDKJ+"SDK_v" + result['fap_version'] + subfix
    if not os.path.isdir(targetDir):
        os.mkdir(targetDir)
    else:
        removeDir(targetDir)
        os.mkdir(targetDir)

    copyHeaderFile(sourceDir, targetDir)

    

    copyDoc(docSrc, targetDir, result['fap_version'])

    winSrc = "D:\\git\\oxi\\GSerWin\\"
    copyWinExe(winSrc, targetDir, result['is_include_alg'])
    copyWinSource(winSrc, targetDir)

    androidSrc = "D:\\git\\oxi\\GSerAndroid\\"
    copyAndroidSrc(androidSrc, targetDir)
    copyAndroidAPK(androidSrc, targetDir)


