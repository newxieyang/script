# !/usr/bin/python
# encoding:utf-8

import shutil
from fileUtils import *


SDKPath = "D:/output/"
ver = ""
_v8a = "arm64-v8a"
_v7a = "armeabi-v7a"


def copyWin(srcDir, libName, targetDir):
    shutil.copy2(srcDir + "scanapi/include/OXiScan_Api.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir)

    print(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".lib")
    # copy x86  D:\output\FAP45\1.0.0.1\vs\win-x64\Release\FAP45.dll
    # shutil.copy2(SDKPath+ "cmake-build-release-vs2019_x86/dev/" + proj + "/Release/"  + libName + ".lib", targetDir + "libx86")
    # shutil.copy2(SDKPath +"cmake-build-release-vs2019_x86/dev/" + proj + "/Release/" + libName + ".dll", targetDir + "Release")
    print( targetDir + "libx64")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".lib", targetDir + "libx64")
    print( targetDir + "x64/Release")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".dll", targetDir + "x64/Release")
    # copy x64
    # shutil.copy2(SDKPath+ "cmake-build-release-vs2019_x64/dev/" + proj + "/Release/"  + libName + ".lib", targetDir + "libx64")
    # shutil.copy2(SDKPath +"cmake-build-release-vs2019_x64/dev/" + proj + "/Release/" + libName + ".dll", targetDir + "x64/Release")
    print( targetDir + "libx86")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x86/Release/" + libName + ".lib", targetDir + "libx86")
    print( targetDir + "Release")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x86/Release/" + libName + ".dll", targetDir + "Release")


def copyAndroid(srcDir,libName, targetDir):
    print(sourceDir + "cmake-build-release-armeabi-v7a/lib" + libName + ".so")
    shutil.copy2(srcDir + "scanapi/include/OXiScan_Api.h", targetDir + "include")
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir+ "include")
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir+ "include")
    # D:\output\FAP45\1.0.0.1\android\arm64-v8a\libFAP45.so
    print( targetDir + _v7a)
    shutil.copy2(sourceDir +  "cmake-build-release-armeabi-v7a/lib" + libName + ".so", targetDir + _v7a)
    print( targetDir + _v8a)
    shutil.copy2(sourceDir +  "cmake-build-release-arm64-v8a/lib" + libName + ".so", targetDir + _v8a)



def copyAlgo(targetAndroid, targetWin, algoVer):
    srcDir = "D:\\git\\oxi\\3rd\\OXi_FP_AIg_V" + algoVer + "\\lib"
    #copy Android v7a
    srcV7a = srcDir + "/Android/armeabi-v7a/"
    shutil.copy2(srcV7a + "libAIAlg.so", targetAndroid + _v7a)
    shutil.copy2(srcV7a + "libOXIAlg.so", targetAndroid + _v7a)
    shutil.copy2(srcV7a + "libTraAlg.so", targetAndroid + _v7a)
    #copy Android v8a
    srcV8a = srcDir + "/Android/arm64-v8a/"
    shutil.copy2(srcDir + "/Android/arm64-v8a/libAIAlg.so", targetAndroid + _v8a)
    shutil.copy2(srcDir + "/Android/arm64-v8a/libOXIAlg.so", targetAndroid + _v8a)
    shutil.copy2(srcDir + "/Android/arm64-v8a/libTraAlg.so", targetAndroid + _v8a)
    # copy Win x64
    shutil.copy2(srcDir + "/vs/win-x64/AIAlg.dll", targetWin + "x64/Release")
    shutil.copy2(srcDir + "/vs/win-x64/OXIAlg.dll", targetWin + "x64/Release")
    shutil.copy2(srcDir + "/vs/win-x64/TraAlg.dll", targetWin + "x64/Release")
    # copy Win x84
    shutil.copy2(srcDir + "/vs/win-x86/AIAlg.dll", targetWin + "Release")
    shutil.copy2(srcDir + "/vs/win-x86/OXIAlg.dll", targetWin + "Release")
    shutil.copy2(srcDir + "/vs/win-x86/TraAlg.dll", targetWin + "Release")


if __name__ == '__main__':
   
    sourceDir = "D:/git/oxi/OXiScan/"

    # libName = ""

    libName = "FAP"

    print(sourceDir)
# sourceDir + "base/include/version.h"
    ver = readVer(sourceDir)
    print(ver)

    winTgDir = "D:\\git\\oxi\\GSerWin\\"
    print(winTgDir)
    copyWin(sourceDir,  libName, winTgDir)

    androidTgDir = "D:\\git\\oxi\\GSerAndroid\\libFAP\\src\\main\\cpp\\"
    print(androidTgDir)
    copyAndroid(sourceDir,  libName, androidTgDir)

    copyAlgo(androidTgDir, winTgDir, "1.0.0.8")
