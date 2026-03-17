# !/usr/bin/python
# encoding:utf-8

import shutil
from utils.fileUtils import *


SDKPath = "D:/output/"
ver = ""
_v8a = "arm64-v8a"
_v7a = "armeabi-v7a"


def copyWin(srcDir, libName, targetDir):
    shutil.copy2(srcDir + "base/export/OXiScan_Api.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir)
    # copy x86
    print(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".lib")
    print( targetDir + "libx64")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".lib", targetDir + "libx64")
    print( targetDir + "x64/Release")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".dll", targetDir + "x64/Release")
    # copy x64
    print( targetDir + "libx86")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x86/Release/" + libName + ".lib", targetDir + "libx86")
    print( targetDir + "Release")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x86/Release/" + libName + ".dll", targetDir + "Release")


def copyAndroid(srcDir,libName, targetDir):
    print(sourceDir + "cmake-build-release-armeabi-v7a/lib" + libName + ".so")
    shutil.copy2(srcDir + "base/export/OXiScan_Api.h", targetDir + "include")
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir+ "include")
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir+ "include")
    print( targetDir + _v7a)
    shutil.copy2(sourceDir +  "cmake-build-release-armeabi-v7a/lib" + libName + ".so", targetDir + _v7a)
    print( targetDir + _v8a)
    shutil.copy2(sourceDir +  "cmake-build-release-arm64-v8a/lib" + libName + ".so", targetDir + _v8a)

def copyWinStatic(srcDir, libName, targetDir):
    shutil.copy2(srcDir + "base/export/OXiScan_Api.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir)
    # copy x86
    print(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".lib")
    print( targetDir + "libx64")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x64/Release/" + libName + ".lib", targetDir + "libx64")
    # copy x64
    print( targetDir + "libx86")
    shutil.copy2(sourceDir +  "cmake-build-release-vs2019_x86/Release/" + libName + ".lib", targetDir + "libx86")


def copyAndroidStatic(srcDir,libName, targetDir):
    print(sourceDir + "cmake-build-release-armeabi-v7a/lib" + libName + ".a")
    shutil.copy2(srcDir + "base/export/OXiScan_Api.h", targetDir + "include")
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir+ "include")
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir+ "include")
    print( targetDir + _v7a)
    shutil.copy2(sourceDir +  "cmake-build-release-armeabi-v7a/lib" + libName + ".a", targetDir + _v7a)
    print( targetDir + _v8a)
    shutil.copy2(sourceDir +  "cmake-build-release-arm64-v8a/lib" + libName + ".a", targetDir + _v8a)

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

    libName = "FAP"

    print(sourceDir)

    result = parse_cmake_versions(sourceDir)
    print(f"算法版本: {result['algorithm_version']}")
    print(f"FAP版本: {result['fap_version']}")
    print(f"是否带算法: {result['is_include_alg']}")
    print(f"完整标识: {result['final_string']}")
    print(f"bulid static: {result['build_static']}")

    
    if(result['build_static']):
        androidLibTgDir = "D:\\git\\oxi\\GSerLibAndroid\\libFAP\\src\\main\\cpp\\"
        copyAndroidStatic(sourceDir,  libName, androidLibTgDir)
        winLibTgDir = "D:\\git\\oxi\\GSerWinStatic\\"
        copyWinStatic(sourceDir,  libName, winLibTgDir)
    else:
        winTgDir = "D:\\git\\oxi\\GSerWinDynamic\\"
        copyWin(sourceDir,  libName, winTgDir)
        androidTgDir = "D:\\git\\oxi\\GSerAndroid\\libFAP\\src\\main\\cpp\\"
        copyAndroid(sourceDir,  libName, androidTgDir)


   

    

    if(result['is_include_alg']):
        print("--" + result['algorithm_version'] + "---")
        # copyAlgo(androidTgDir, winTgDir, algoVer)
    else:
        print("--no algo---")
    

    
