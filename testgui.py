import tkinter as tk
 
root = tk.Tk()
root.title("Grid Layout Example")
 
label1 = tk.Label(root, text="Label 1")
label2 = tk.Label(root, text="Label 2")
entry1 = tk.Entry(root)
button1 = tk.Button(root, text="Button 1")
 
# 使用grid布局
label1.grid(row=0, column=0, sticky="e")  # sticky="e" 表示标签文本靠右对齐
label2.grid(row=1, column=0, sticky="e")
entry1.grid(row=0, column=1, padx=5, pady=5)  # padx和pady添加间距
button1.grid(row=1, column=1)
 
root.mainloop()