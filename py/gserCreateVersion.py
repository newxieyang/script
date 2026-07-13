# !/usr/bin/python
# encoding:utf-8

import shutil
import os
import glob
from utils.copyUtils import copy_android_apk, copy_android_source_code, copy_win_exe, copy_win_source_code
from utils.fileUtils import remove_dir, safe_mkdir, parse_cmake_versions


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


def copyDoc(srcDir, targetDir, SDKver):
    if os.path.isdir(targetDir + "doc"):
        remove_dir(targetDir+"/doc")
    shutil.copytree(srcDir, targetDir+"/doc")

    directory = targetDir+"/doc"
    docx_files = glob.glob(os.path.join(directory, '*.docx'))

    if not docx_files:
        print(f"在目录 {directory} 中没有找到任何.docx文件。")
        return
    docx_files.sort(key=os.path.getmtime)

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
        safe_mkdir(tgHeader)
    # print("src:" + srcDir+ "/libFAP/include/")
    src_file = os.path.join(srcDir, "base", "export", "OXiScan_Api.h")
    shutil.copy2(src_file, tgHeader)
    src_file = os.path.join(srcDir, "base", "include", "OXiScan_def.h")
    shutil.copy2(src_file, tgHeader)
    src_file = os.path.join(srcDir, "base", "include", "OXiScan_err.h")
    shutil.copy2(src_file, tgHeader)


if __name__ == '__main__':
  
    BASE_SOURCE = r"D:/git/oxi/shenzhen"
    CUSTOM_STR = "oxiscansdk"
    SDK_DIR = os.path.join(BASE_SOURCE, f"{CUSTOM_STR}")
    
    libName = "FAP"
    SDKJ = "OXi_FP_"
   
    result = parse_cmake_versions(SDK_DIR)
    print("SDKver:" + result['fap_version'] + ";")

    subfix = "Static" if result.get('build_static') else "dy"

    targetDir = "D:/GSerSDKLib/"+SDKJ+"SDK_v" + result['fap_version']+ subfix
    if not os.path.isdir(targetDir):
        safe_mkdir(targetDir)
    else:
        remove_dir(targetDir)
        safe_mkdir(targetDir)

    copyHeaderFile(SDK_DIR, targetDir)
    
    docSrc = "D:/GSerSDKLib/doc"
    copyDoc(docSrc, targetDir, result['fap_version'])


    win_source_path = os.path.join(BASE_SOURCE,  f"{CUSTOM_STR}_win")
    android_source_path = os.path.join(BASE_SOURCE,  f"{CUSTOM_STR}_Android")

      # Windows产物
    print("\n2. 复制Windows Demo程序")
    copy_win_exe(win_source_path, targetDir)
    print("\n3. 复制Windows源码工程")
    copy_win_source_code(win_source_path, targetDir)

    # Android产物
    print("\n4. 复制Android源码工程")
    copy_android_source_code(android_source_path, targetDir)
    print("\n5. 复制Android APK安装包")
    copy_android_apk(android_source_path, targetDir)

