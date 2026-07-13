# !/usr/bin/python
# encoding:utf-8

from tkinter import *
from tkinter import scrolledtext
import os

cmd_pull="adb pull {a_path} {l_path}"
cmd_push="adb push {l_path} {a_path}"
cmd_win_del=""
cmd_adb_del="adb shell rm -rf {a_path}/*"

adb_path="/storage/emulated/0/oxi/"
local_path="D:/0"

def exec_cmd(cmd):
    txta.insert(END, cmd + "\n")
    result = os.popen(cmd)
    res = result.read()
    for line in res.splitlines():  
        txta.insert(END, line + "\n")

def get_adb_path(folder):
    path = txt.get()
    if not path.endswith("/"):
        path +="/"
    return txt.get() + folder

def get_local_path():
    local_path = txt1.get()
    if not os.path.exists(local_path):
        os.makedirs(local_path)
    return local_path

def exec_pull_cmd(folder):
    exec_cmd(cmd_pull.format(a_path=get_adb_path(folder), l_path=get_local_path()))

def exec_push_cmd(folder):
    exec_cmd(cmd_push.format(a_path=get_adb_path(folder), l_path=get_local_path()+"/."))

def exec_del_cmd(folder):
    exec_cmd(cmd_adb_del.format(a_path=get_adb_path(folder)))

# pull function
def pull_oxi():
    exec_pull_cmd("")

def pull_log():
   exec_pull_cmd("log")

def pull_auth():
    exec_pull_cmd("auth")

def pull_enroll():
    exec_pull_cmd("enroll")

def pull_tpl():
    exec_pull_cmd("tpl")

def pull_cali():
    exec_pull_cmd("cali")

def pull_model():
    exec_pull_cmd("model")

## del function
def del_oxi():
    exec_del_cmd("")

def del_log():
    exec_del_cmd("log")

def del_auth():
    exec_del_cmd("auth")

def del_enroll():
    exec_del_cmd("enroll")

def del_tpl():
    exec_del_cmd("tpl")

def del_cali():
    exec_del_cmd("cali")

def del_model():
    exec_del_cmd("model")

## push function
def push_cali():
    exec_push_cmd("cali")

def push_auth():
    exec_push_cmd("auth")

def push_enroll():
    exec_push_cmd("enroll")


window = Tk()
window.title("Oxi adb tools")
lbl = Label(window, text="adb 路径")
lbl.grid(column=0, row=0)

txt = Entry(window, width=100)
txt.insert(INSERT, adb_path)
txt.grid(column=1, row=0, columnspan=3)

lb2 = Label(window, text="本地路径")
lb2.grid(column=0, row=1)

txt1 = Entry(window, width=100)
txt1.insert(INSERT, local_path)
txt1.grid(column=1, row=1, columnspan=3)

# pull function
btn = Button(window, text="拉取oxi文件到本地", command=pull_oxi, width=20)
btn.grid(column=0, row=2, sticky=N, ipadx=10)


btn = Button(window, text="拉取log文件到本地", command=pull_log, width=20)
btn.grid(column=1, row=2, sticky=N, ipadx=10)


btn = Button(window, text="拉取auth文件到本地", command=pull_auth, width=20)
btn.grid(column=2, row=2, sticky=N, ipadx=10)


btn = Button(window, text="拉取enroll文件到本地",width=20, command=pull_enroll)
btn.grid(column=3, row=2, sticky=N, ipadx=10)


btn = Button(window, text="拉取tpl文件到本地",width=20, command=pull_tpl)
btn.grid(column=0, row=3, sticky=N, ipadx=10)

btn = Button(window, text="拉取model文件到本地",width=20, command=pull_model)
btn.grid(column=1, row=3, sticky=N, ipadx=10)


btn = Button(window, text="拉取cali文件到本地",width=20, command=pull_cali)
btn.grid(column=2, row=3, sticky=N, ipadx=10)

## del function

btn = Button(window, text="删除oxi文件夹",width=20, command=del_oxi)
btn.grid(column=0, row=4, sticky=N, ipadx=10)


btn = Button(window, text="删除log文件夹",width=20, command=del_log)
btn.grid(column=1, row=4, sticky=N, ipadx=10)


btn = Button(window, text="删除auth文件夹",width=20, command=del_auth)
btn.grid(column=2, row=4, sticky=N, ipadx=10)


btn = Button(window, text="删除enroll文件夹",width=20, command=del_enroll)
btn.grid(column=3, row=4, sticky=N, ipadx=10)


btn = Button(window, text="删除tpl文件夹",width=20, command=del_tpl)
btn.grid(column=0, row=5, sticky=N, ipadx=10)

btn = Button(window, text="删除cali文件夹",width=20, command=del_cali)
btn.grid(column=1, row=5, sticky=N, ipadx=10)


btn = Button(window, text="删除tpl文件夹",width=20, command=del_tpl)
btn.grid(column=2, row=5, sticky=N, ipadx=10)

# pull function
# btn = Button(window, text="推送auth文件到手机",width=20, command=push_auth)
# btn.grid(column=0, row=6, sticky=N, ipadx=10)

# btn = Button(window, text="推送cali文件到手机",width=20, command=push_cali)
# btn.grid(column=1, row=6, sticky=N, ipadx=10)

# btn = Button(window, text="推送enroll文件到手机",width=20, command=push_enroll)
# btn.grid(column=2, row=6, sticky=N, ipadx=10)

txta = scrolledtext.ScrolledText(window, width=120, height=10)
txta.grid(column=0, row=8, columnspan=4)

# root = tk.Tk()÷
col_count, row_count = window.grid_size()
 
for col in range(col_count):
    window.grid_columnconfigure(col, minsize=20)
 
for row in range(row_count):
    window.grid_rowconfigure(row, minsize=20)

window.mainloop()