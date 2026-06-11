# !/usr/bin/python
# encoding:utf-8

import shutil


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


if __name__ == '__main__':
    custom = ["_ARATEK", "_MIAXIS", "_win7", "_fangzheng", "_new", "_kejin", "_yinken", "_huantian", "_Thales", "_mantra"]
    sourceDir = "D:/git/oxi/g6/"
    libName = "FAP60"
    index = 9
    customStr = custom[index]
    SDKDir = sourceDir+"FAP6010" + customStr + "/"
    cus="OXi"
    if index == 9:
        cus=""
    print(sourceDir)

    winTgDir = sourceDir + "g6010WinDemo"+ customStr + "/"
    print(winTgDir)
    copyWin(SDKDir, libName, winTgDir, cus)

    androidTgDir = sourceDir + "G6010Android"+ customStr + "/libFAP/src/main/cpp/"
    print(androidTgDir)
    copyAndroid(SDKDir, libName, androidTgDir, cus)
