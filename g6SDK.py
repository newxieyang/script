# !/usr/bin/python
# encoding:utf-8

import shutil


def copyWin(srcDir, libName, targetDir):
    shutil.copy2(srcDir + "libFAP/include/OXiScanAPI.h", targetDir)
    shutil.copy2(srcDir + "libFAP/include/OXiScanUltimate.h", targetDir)
    shutil.copy2(srcDir + "libFAP/include/OXiScanUltimateApi_err.h", targetDir)
    # copy x86
    shutil.copy2(srcDir+ "cmake-build-release-vs2019_x86/libFAP/Release/"  + libName + ".lib", targetDir)
    shutil.copy2(srcDir +"cmake-build-release-vs2019_x86/libFAP/Release/" + libName + ".dll", targetDir)
    # copy x64
    shutil.copy2(srcDir+ "cmake-build-release-vs2019_x64/libFAP/Release/"  + libName + ".lib", targetDir)
    shutil.copy2(srcDir +"cmake-build-release-vs2019_x64/libFAP/Release/" + libName + ".dll", targetDir)


def copyAndroid(srcDir, libName, targetDir):
    shutil.copy2(srcDir + "libFAP/include/OXiScanAPI.h", targetDir + "include")
    shutil.copy2(srcDir + "libFAP/include/OXiScanUltimate.h", targetDir+ "include")
    shutil.copy2(srcDir + "libFAP/include/OXiScanUltimateApi_err.h", targetDir+ "include")

    shutil.copy2(srcDir + "cmake-build-release-armeabi-v7a/libFAP/lib" + libName + ".so", targetDir)
    shutil.copy2(srcDir + "cmake-build-release-arm64-v8a/libFAP/lib" + libName + ".so", targetDir)


if __name__ == '__main__':
    custom = ["_ARATEK", "_MIAXIS", "_win7", "_fangzheng", "_new", "_kejin", "_yinken", "_huantian", "_Thales"]
    sourceDir = "D:/git/oxi/g6/"
    libName = "FAP"
    SDKDir = sourceDir+"FAP6010" + custom[1] + "/"

    winTgDir = sourceDir + "g6010WinDemo_"+ custom[1] + "/"
    copyWin(SDKDir, libName, winTgDir)

    androidTgDir = sourceDir + "G6010Android_"+ custom[1] + "/libFAP/src/main/cpp/"
    copyAndroid(SDKDir, libName, androidTgDir)
