# !/usr/bin/python
# encoding:utf-8


import tkinter as tk
from tkinter import ttk
from tkinter import scrolledtext
from tkinter import *
import os


pjlist=['G2','G45','G60','G70']
culist=[
    ["硕腾","源码"],
    ["oxi","huangtian"],
    ["OXi", "中正", "亚略特"]]

sourDirslist=[
    ["硕腾","源码"],
    ["oxi","huangtian"],
    ["OXi", "中正", "亚略特"]]

winDirlist=[
    ["硕腾","源码"],
    ["oxi","huangtian"],
    ["OXi", "中正", "亚略特"]]
andoirdDirlist=[
    ["硕腾","源码"],
    ["oxi","huangtian"],
    ["OXi", "中正", "亚略特"]]


def on_gen_win_click():
    label1.config(text="按钮被点击！")

def on_gen_android_click():
    label1.config(text="按钮被点击！")

def on_copy_win_click():
    label1.config(text="按钮被点击！")

def on_gen_win_click():
    label1.config(text="按钮被点击！")

def on_copy_android_click(event):
    print(f"当前选择: {combo1.get()}")
   

def on_prj_changed(event):
    print(f'当前选择客户: {combo2.get()}')
    combo2['values'] = culist[combo1.current()]
    combo2.set(culist[combo1.current()][0])


def on_custom_change(event):
    print(f'当前选择客户: {combo2.get()}')
 
app = tk.Tk()
app.geometry("800x700")
app.title("Tkinter 示例")

# button = tk.Button(app, text="点击我", command=on_button_click)
# button.pack()


 
label1 = tk.Label(app, text="项目", width=20)

combo1 = ttk.Combobox(app, values=pjlist, width=10)
# combo1.set("G45")  # 设置初始值
combo1.set(pjlist[0])
combo1.bind("<<ComboboxSelected>>", on_prj_changed)


label2 = tk.Label(app, text="客户", width=20)

combo2 = ttk.Combobox(app, values=culist[0], width=10)
combo2.set("OXi")  # 设置初始值
combo2.bind("<<ComboboxSelected>>", on_custom_change)

label1.grid(row=0, column=0, columnspan=2)
combo1.grid(row=0, column=3, columnspan=2, sticky=N, ipadx=10)
txt = Entry(app, width=80)
txt.insert(INSERT, sourDirslist[0][0])
txt.grid(row=0, column=5, columnspan=3, sticky=N, ipadx=10)


label2.grid(row=1, column=0, columnspan=2)
combo2.grid(row=1, column=3, columnspan=2 , sticky=N, ipadx=10)
txt1 = Entry(app, width=80)
txt1.insert(INSERT, winDirlist[0][0])
txt1.grid(row=1, column=5, columnspan=3, sticky=N, ipadx=10)

txt2 = Entry(app, width=80)
txt2.insert(INSERT, andoirdDirlist[0][0])
txt2.grid(row=2, column=5, columnspan=3, sticky=N, ipadx=10)

# button = tk.Button(app, text="生成Win库", command=on_gen_win_click)
# button = tk.Button(app, text="生成Android库", command=on_gen_android_click)
# button = tk.Button(app, text="拷贝Win库", command=on_copy_win_click)
# button = tk.Button(app, text="拷贝Android库", command=on_copy_android_click)

app.mainloop()