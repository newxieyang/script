# !/usr/bin/python
# encoding:utf-8
import shutil

import os


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






if __name__ == '__main__':
    base_dir = 'D:\\0\\org\\finger'
    print("dir:%s" % (base_dir))
    list_file(base_dir)










