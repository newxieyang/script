# !/usr/bin/python
# encoding:utf-8

import shutil
import os
import chardet


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


def ignore_predicate(src_dir, names):
    # 定义需要忽略的文件夹名列表
    ignore_folders = ['Release', 'x64', '.vs']
    ignored_names = []
    for name in names:
        full_path = os.path.join(src_dir, name)
        if os.path.isdir(full_path) and name in ignore_folders:
            ignored_names.append(name)
    return ignored_names

def readSDKVer(sourceDir, customStr):
    verFilepathName=sourceDir + "/libFAP/include/Version.h"
    ver = ""
    with open(verFilepathName, "r") as file:
        for line in file:
            if "#define OXISCAN_VERSION_MAJOR" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "") + "."
            if "#define OXISCAN_VERSION_MINOR" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "") + "."
            if "#define OXISCAN_VERSION_PATCH" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "") + "."
            if "#define OXISCAN_VERSION_BUILD" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "")
    return ver

def readMkVer(sourceDir, customStr):
    verFilepathName=sourceDir +  "/OXiMKImgLib/src/oxi_mk_image_process.cpp"
    with open(verFilepathName, 'rb') as file:
        raw_data = file.read()
        result = chardet.detect(raw_data)
        encoding = result['encoding']
    ver = ""
    with open(verFilepathName, "r", encoding=encoding) as file:
        for line in file:
            if "version[0]" in line:
                ver += line.split("=")[1].replace(" ", "").replace(";", "").replace("\n", "") + "."
            if "version[1]" in line:
                ver += line.split("=")[1].replace(" ", "").replace(";", "").replace("\n", "") + "."
            if "version[2]" in line:
                ver += line.split("=")[1].replace(" ", "").replace(";", "").replace("\n", "")
    return ver


def copyWin(srcDir, libName, targetDir, cus):
    shutil.copy2(srcDir + "libFAP/include/"+cus+"ScanAPI.h", targetDir)
    shutil.copy2(srcDir + "libFAP/include/"+cus+"ScanUltimate.h", targetDir)
    shutil.copy2(srcDir + "libFAP/include/"+cus+"ScanUltimateApi_err.h", targetDir)
    # copy x86
    shutil.copy2(srcDir+ "cmake-build-release-vs2019_x86/libFAP/Release/"  + libName + ".lib", targetDir + "libx86")
    shutil.copy2(srcDir +"cmake-build-release-vs2019_x86/libFAP/Release/" + libName + ".dll", targetDir + "Release")
    # copy x64
    shutil.copy2(srcDir+ "cmake-build-release-vs2019_x64/libFAP/Release/"  + libName + ".lib", targetDir + "libx64")
    shutil.copy2(srcDir +"cmake-build-release-vs2019_x64/libFAP/Release/" + libName + ".dll", targetDir + "x64/Release")



def copyAndroid(srcDir, libName, targetDir, cus):
    shutil.copy2(srcDir + "libFAP/include/"+cus+"ScanAPI.h", targetDir + "include")
    shutil.copy2(srcDir + "libFAP/include/"+cus+"ScanUltimate.h", targetDir+ "include")
    shutil.copy2(srcDir + "libFAP/include/"+cus+"ScanUltimateApi_err.h", targetDir+ "include")

    shutil.copy2(srcDir + "cmake-build-release-armeabi-v7a/libFAP/lib" + libName + ".so", targetDir + "armeabi-v7a")
    shutil.copy2(srcDir + "cmake-build-release-arm64-v8a/libFAP/lib" + libName + ".so", targetDir + "arm64-v8a")


def copyDoc(srcDir, targetDir):
    if os.path.isdir(targetDir + "doc"):
        removeDir(targetDir+"/doc")
    shutil.copytree(srcDir, targetDir+"/doc")


def copyHeaderFile(srcDir,customStr, targetDir, cus):
    tgHeader = targetDir+"/include"
    if os.path.isdir(tgHeader):
        shutil.rmtree(tgHeader)
    else:
        os.mkdir(tgHeader)
    print("tgHeader:" + tgHeader)
    print("src:" + srcDir+ "/libFAP/include/")
    shutil.copy2(srcDir+ "/libFAP/include/"+cus+"ScanAPI.h", tgHeader)
    shutil.copy2(srcDir+ "/libFAP/include/"+cus+"ScanUltimate.h", tgHeader)
    shutil.copy2(srcDir+ "/libFAP/include/"+cus+"ScanUltimateApi_err.h", tgHeader)



def copyWinExe(srcDir,customStr, tgDir):
    #copy x86
    exe86Src = srcDir + "g6010WinDemo_" + customStr + "/Release/"
    print(exe86Src)
    tgx86 = tgDir + "/winx86DemoWithLib"
    if not os.path.isdir(tgx86):
        os.mkdir(tgx86)

    # def traverse_directory(exe86Src):
    for root, dirs, files in os.walk(exe86Src):
        for file in files:
            if file.endswith(".exe"):
                shutil.copy2(os.path.join(root, file), tgx86)
            if file.endswith(".dll"):
                shutil.copy2(os.path.join(root, file), tgx86)


    exe64Src = srcDir + "g6010WinDemo_" + customStr + "/x64/Release/"
    tgx64 = tgDir + "/winx64DemoWithLib"
    if not os.path.isdir(tgx64):
        os.mkdir(tgx64)
    # def traverse_directory(exe64Src):
    for root, dirs, files in os.walk(exe64Src):
        for file in files:
            if file.endswith(".exe"):
                shutil.copy2(os.path.join(root, file), tgx64)
            if file.endswith(".dll"):
                shutil.copy2(os.path.join(root, file), tgx64)


def copyWinSource(sourceDir, customStr, target):
    srcDir = sourceDir + "g6010WinDemo_" + customStr
    tgDir = target + "/winSimpleCode"
    if os.path.isdir(tgDir):
        removeDir(tgDir)
    
    shutil.copytree(srcDir, tgDir, ignore=ignore_predicate)


def ignore_predicate_Android(src_dir, names):
    # 定义需要忽略的文件夹名列表
    ignore_folders = ['.gradle', '.git', '.idea', "build", ".cxx"]
    ignored_names = []
    for name in names:
        full_path = os.path.join(src_dir, name)
        if os.path.isdir(full_path) and name in ignore_folders:
            ignored_names.append(name)
    return ignored_names 

def copyAndroidSrc(srcDir, customStr, target):
    tgDir = target + "/Andoird/ScannerSimple"
    shutil.copytree(srcDir, tgDir, ignore=ignore_predicate_Android)

def copyAndroidAPK(srcDir, target):
    srouceDir = srcDir + "/app/build/outputs/apk/debug"
    tgDir = target + "/Andoird"
    for root, dirs, files in os.walk(srouceDir):
        for file in files:
            if file.endswith(".apk"):
                shutil.copy2(os.path.join(root, file), tgDir)

if __name__ == '__main__':
    custom = ["ARATEK", "MIAXIS", "win7", "fangzheng", "new", "kejin", "yinken", "huantian", "Thales", "mantra"]
    sourceDir = "D:/git/oxi/g6/"
    libName = "FAP60"
    index = 9
    customStr = custom[index]
    SDKDir = sourceDir+"FAP6010_" + customStr + "/"
    cus="OXi"
    if index == 9:
        cus=""
       
    print(sourceDir)
    targetDir="D:/G6SDKLib/" + customStr
 
    if not os.path.isdir(targetDir):
        os.mkdir(targetDir)

    SDKver = readSDKVer(SDKDir, customStr)
    print("SDKver:" + SDKver + ";")

    MKver = readMkVer(SDKDir, customStr)
    print("MKver:" + MKver + ";")

    targetDir += "/G6SDKv" + SDKver+"mk"+MKver
    if not os.path.isdir(targetDir):
        os.mkdir(targetDir)

    copyHeaderFile(SDKDir, customStr, targetDir, cus)

    

    copyDoc("D:\G6SDKLib\doc", targetDir)

    copyWinExe(sourceDir,customStr, targetDir)
    copyWinSource(sourceDir, customStr, targetDir)

    androidSrc = sourceDir + "G6010Android_" + customStr
    copyAndroidSrc(androidSrc, customStr, targetDir)

    copyAndroidAPK(androidSrc, targetDir)

    # winTgDir = sourceDir + "g6010WinDemo"+ customStr + "/"
    # print(winTgDir)
    # copyWin(SDKDir, libName, winTgDir, cus)

    # androidTgDir = sourceDir + "G6010Android"+ customStr + "/libFAP/src/main/cpp/"
    # print(androidTgDir)
    # copyAndroid(SDKDir, libName, androidTgDir, cus)
