# !/usr/bin/python
# encoding:utf-8
import shutil

import os
from fileUtils import *


arr = []    
def list_file(base):
    print("dir:%s" % (base))
    for root, ds, fs in os.walk(base):
        for f in fs:
            # print(f)
            if ".raw_" in f:
                # 构造原始文件路径
                src_file = os.path.join(root, f)
                # 构造新文件路径
                dst_file = os.path.join(root,  f[:-1])
                # 重命名文件
                shutil.move(src_file, dst_file)


def is_hidden(path):
    """判断路径是否为隐藏文件或目录"""
    basename = os.path.basename(path)
    return basename.startswith('.') or (os.name == 'nt' and basename.startswith('$') or basename.startswith('cmake')  or basename.startswith('src'))
 

def findVersionFilePath(pjDir):
    for root, dirs, files in os.walk(pjDir):
    # 忽略隐藏目录
        dirs[:] = [d for d in dirs if not is_hidden(d)]
        # for dir in dirs:
        #     print(f"Directory: {os.path.join(root, dir)}")
        for file in files:
            print(f"File: {os.path.join(root, file)}")
            if "ersion" in file:
                return os.path.join(root, file)

    # for root, ds, fs in os.walk(pjDir):
    #     for file_name in fs:
    #         if not file_name.startswith(".") and not file_name.startswith("cmake"):
    #             print(file_name)
    #             file_path = os.path.join(pjDir, file_name)
    #             if os.path.isdir(file_path):
    #                 findVersionFilePath(file_path)
    #             if "ersion" in file_name:
    #                 return file_path 



if __name__ == '__main__':
    # base_dir = 'D:\\0\\org\\finger'
    # print("dir:%s" % (base_dir))
    # list_file(base_dir)
    # print(findVersionFilePath("D:\git\oxi\g6\FAP6010_Thales"))
    print(readVer('D:\\git\\oxi\\g6\\FAP6010_Thales'))











