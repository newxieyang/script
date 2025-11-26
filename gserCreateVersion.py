# !/usr/bin/python
# encoding:utf-8

import shutil
import os
import chardet
import glob
from fileUtils import *


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




    

# def readMkVer(sourceDir, customStr):
#     verFilepathName=sourceDir +  "/OXiMKImgLib/src/oxi_mk_image_process.cpp"
#     with open(verFilepathName, 'rb') as file:
#         raw_data = file.read()
#         result = chardet.detect(raw_data)
#         encoding = result['encoding']
#     ver = ""
#     with open(verFilepathName, "r", encoding=encoding) as file:
#         for line in file:
#             if "version[0]" in line:
#                 ver += line.split("=")[1].replace(" ", "").replace(";", "").replace("\n", "") + "."
#             if "version[1]" in line:
#                 ver += line.split("=")[1].replace(" ", "").replace(";", "").replace("\n", "") + "."
#             if "version[2]" in line:
#                 ver += line.split("=")[1].replace(" ", "").replace(";", "").replace("\n", "")
#                 return ver
    


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


# def getDoc(targetDir, sdkVer):



def copyDoc(srcDir, targetDir, SDKver):
    if os.path.isdir(targetDir + "doc"):
        removeDir(targetDir+"/doc")
    shutil.copytree(srcDir, targetDir+"/doc")
    # 指定目录
    directory = targetDir+"/doc"

    # 获取指定目录下的所有.docx文件
    docx_files = glob.glob(os.path.join(directory, '*.docx'))

    # 如果没有.docx文件，则直接退出
    if not docx_files:
        print(f"在目录 {directory} 中没有找到任何.docx文件。")
        return

    # 根据文件的最后修改时间进行排序，最近的文件会排在最后
    docx_files.sort(key=os.path.getmtime)

    # 保留最近的一个文件，删除其他的
    for file in docx_files[:-1]:
        try:
            os.remove(file)
            print(f"已删除文件: {file}")
        except Exception as e:
            print(f"删除文件 {file} 时出错: {e}")



def copyHeaderFile(srcDir, targetDir):
    tgHeader = targetDir+"/include"
    if os.path.isdir(tgHeader):
        shutil.rmtree(tgHeader)
    else:
        os.mkdir(tgHeader)
    print("tgHeader:" + tgHeader)
    # print("src:" + srcDir+ "/libFAP/include/")
    shutil.copy2(srcDir + "scanapi/include/OXiScan_Api.h", tgHeader)
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", tgHeader)
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", tgHeader)




def copyWinExe(srcDir, tgDir):
    #copy x86
    exe86Src = srcDir + "/Release/"
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


    exe64Src = srcDir +  "/x64/Release/"
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


def ignore_predicate(src_dir, names):
    # 定义需要忽略的文件夹名列表
    ignore_folders = ['Release', 'x64', '.vs', '.git']
    ignored_names = []
    for name in names:
        full_path = os.path.join(src_dir, name)
        if os.path.isdir(full_path) and name in ignore_folders:
            ignored_names.append(name)
    return ignored_names


def copyWinSource(srcDir, target):
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

def copyAndroidSrc(srcDir, target):
    tgDir = target + "/Andoird/ScannerSimple"
    shutil.copytree(srcDir, tgDir, ignore=ignore_predicate_Android)

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

    SDKver = readCmakeVer(sourceDir)
    print("SDKver:" + SDKver + ";")

    # MKver = readMkVer(SDKDir, customStr)
    # print("MKver:" + MKver + ";")
    docSrc = "D:/GSerSDKLib/doc"

    targetDir = "D:/GSerSDKLib/"+SDKJ+"SDK_v" + SDKver
    if not os.path.isdir(targetDir):
        os.mkdir(targetDir)
    else:
        removeDir(targetDir)
        os.mkdir(targetDir)

    copyHeaderFile(sourceDir, targetDir)

    

    copyDoc(docSrc, targetDir, SDKver)

    winSrc = "D:\\git\\oxi\\GSerWin\\"
    copyWinExe(winSrc, targetDir)
    copyWinSource(winSrc, targetDir)

    androidSrc = "D:\\git\\oxi\\GSerAndroid\\"
    copyAndroidSrc(androidSrc, targetDir)
    copyAndroidAPK(androidSrc, targetDir)


