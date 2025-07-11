# !/usr/bin/python
# encoding:utf-8

import shutil


SDKPath = "D:/output/"
ver = ""

def readSDKVer(sourceDir, proj):
    verFilepathName=sourceDir + "dev/"+proj+"/include/version.h"
    print(verFilepathName)
    global ver
    with open(verFilepathName, "r") as file:
        for line in file:
            if "#define VERSION_MAJOR" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "") + "."
            if "#define VERSION_MINOR" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "") + "."
            if "#define VERSION_PATCH" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "") + "."
            if "#define VERSION_BUILD" in line:
                ver += line.split(" ")[2].replace(" ", "").replace("\n", "")
                return ver

def copyWin(srcDir, proj, libName, targetDir):
    shutil.copy2(srcDir + "scanapi/include/OXiScan_Api.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir)
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir)

    print(SDKPath + proj+ "/"  + ver + "/vs/win-x64/Release/" + libName + ".lib")
    # copy x86  D:\output\FAP45\1.0.0.1\vs\win-x64\Release\FAP45.dll
    # shutil.copy2(SDKPath+ "cmake-build-release-vs2019_x86/dev/" + proj + "/Release/"  + libName + ".lib", targetDir + "libx86")
    # shutil.copy2(SDKPath +"cmake-build-release-vs2019_x86/dev/" + proj + "/Release/" + libName + ".dll", targetDir + "Release")
    print( targetDir + "libx64")
    shutil.copy2(SDKPath + proj+ "/"  + ver + "/vs/win-x64/Release/" + libName + ".lib", targetDir + "libx64")
    print( targetDir + "x64/Release")
    shutil.copy2(SDKPath + proj+ "/"  + ver + "/vs/win-x64/Release/" + libName + ".dll", targetDir + "x64/Release")
    # copy x64
    # shutil.copy2(SDKPath+ "cmake-build-release-vs2019_x64/dev/" + proj + "/Release/"  + libName + ".lib", targetDir + "libx64")
    # shutil.copy2(SDKPath +"cmake-build-release-vs2019_x64/dev/" + proj + "/Release/" + libName + ".dll", targetDir + "x64/Release")
    print( targetDir + "libx86")
    shutil.copy2(SDKPath + proj+ "/"  + ver + "/vs/win-x86/Release/" + libName + ".lib", targetDir + "libx86")
    print( targetDir + "Release")
    shutil.copy2(SDKPath + proj+ "/"  + ver + "/vs/win-x86/Release/" + libName + ".dll", targetDir + "Release")


def copyAndroid(srcDir,proj, libName, targetDir):
    print(SDKPath + proj+ "/"  + ver + "/android/arm64-v8a/lib" + libName + ".so")
    shutil.copy2(srcDir + "scanapi/include/OXiScan_Api.h", targetDir + "include")
    shutil.copy2(srcDir + "base/include/OXiScan_def.h", targetDir+ "include")
    shutil.copy2(srcDir + "base/include/OXiScan_err.h", targetDir+ "include")
    # D:\output\FAP45\1.0.0.1\android\arm64-v8a\libFAP45.so
    print( targetDir + "armeabi-v7a")
    shutil.copy2(SDKPath + proj+ "/"  + ver + "/android/armeabi-v7a/lib" + libName + ".so", targetDir + "armeabi-v7a")
    print( targetDir + "arm64-v8a")
    shutil.copy2(SDKPath + proj+ "/" + ver + "/android/arm64-v8a/lib" + libName + ".so", targetDir + "arm64-v8a")




if __name__ == '__main__':
   
    sourceDir = "D:/git/oxi/OXiScan/"

    # libName = ""

    libName = "FAP70"
    projName = libName.lower()

    print(sourceDir)

    readSDKVer(sourceDir, projName)
    print(ver)

    winTgDir = "D:\\git\\oxi\\GSerWin\\"
    print(winTgDir)
    copyWin(sourceDir, projName,  libName, winTgDir)

    androidTgDir = "D:\\git\\oxi\\GSerAndroid\\libFAP\\src\\main\\cpp\\"
    print(androidTgDir)
    copyAndroid(sourceDir, projName, libName, androidTgDir)
