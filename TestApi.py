# !/usr/bin/python
# encoding:utf-8


APIPathName = "D://git//oxi//g6//FAP6010_win7//libFAP//include//OXiScanAPI.h"

def readFunInfo(funName):

    f = open(file=APIPathName)
    liner = []
    index = 0
    havaBreak = True
    for line in f:
        
        liner.append(line.replace('\n', '').replace('\r', '').replace('\r\n', ''))
        # cindex = line.find("rief")
        # print("search: " + line)
        if "brief" in line:
        # if cindex != -1:
            if havaBreak:
                liner.clear()
                liner.append(line.replace('\n', '').replace('\r', '').replace('\r\n', ''))
            else:
                havaBreak = True
           
            
        # index = line.find(funName)
        # if index != -1:
        #     break
        if funName.lower() in line.lower():
            print("liner in ")
            break
                
    return liner


def getFuntionName(funStr):
    str = funStr.split("(")[0]
    str = str.replace("  ", " ")
    return str.split(" ")[2]

def readAPI():
    f = open(file=APIPathName)
    liner = []
    for line in f:
        if "OXISCAN_API" in line:
            if "OXi_" in line:
                liner.append(getFuntionName(line))
    return liner


if __name__ == '__main__':

    funNames = readAPI()
    for item in funNames:
        print("----" + item + "--------------")
        verName = readFunInfo(item)
        for item in verName:
            print(item)
        print("---------------------------------------------------")
    # verName = readFunInfo("OXi_openDevice")
    # print("---------------------------------------------------")
    # for item in verName:
    #     print(item)
    # print("---------------------------------------------------")