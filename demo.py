import wx 
import os
from genSDKAPI import createSDKAPI
from g6CreateVersion import createVersion

gitDir="D:/git/oxi/"

def checkTools():
    return True


def findProject(pjName):
    for file_name in os.listdir(gitDir):
        file_path = os.path.join(gitDir, file_name)
        if os.path.isdir(file_path):
            if file_name == pjName:
                return file_path
       
def findVersionFilePath(dirPj):
    for file_name in os.listdir(dirPj):
        if file_name.endswith("ersion.h"):
            file_path = os.path.join(gitDir, file_name)
            return file_path 


class MyFrame(wx.Frame):

    dirPj = "d:/git/oxi"
    dirWIN = ""
    dirAndroid = ""
    dirTarget = "D:/G6SDKLib/doc"
    selectPj = ""
    selectCustom = ""

    def __init__(self,parent):
        super().__init__(None, title="GridBagSizer 示例")

        # 创建一个 BoxSizer 作为外层 sizer
        outer_sizer = wx.BoxSizer(wx.VERTICAL)

        # 创建一个 GridBagSizer
        grid_sizer = wx.GridBagSizer(5, 5)  # 行间距和列间距为 5

       
        #项目
        grid_sizer.Add(wx.StaticText(self, label="Project"), pos=(0, 0), flag=wx.ALIGN_CENTER_VERTICAL, border=10)
        project_choice = [u"G2", u"G4", u"G6", u"G7"]
        self.choicePJ = wx.Choice(self, wx.ID_ANY, wx.DefaultPosition, wx.Size(80, 25), project_choice, 0)
        self.choicePJ.SetSelection(0)
        self.choicePJ.Bind(wx.EVT_CHOICE, self.project_choice)
        grid_sizer.Add(self.choicePJ, pos=(0, 1), flag=wx.EXPAND|wx.ALL, border=10)

        #项目
        grid_sizer.Add(wx.StaticText(self, label="Pj Dir"), pos=(1, 0), flag=wx.ALIGN_CENTER_VERTICAL, border=10)
        self.txt_pj = wx.TextCtrl(self, size = (200, -1))
        grid_sizer.Add(self.txt_pj, pos=(1, 1), flag=wx.EXPAND|wx.ALL, border=10)

        #客户
        grid_sizer.Add(wx.StaticText(self, label="Custom"), pos=(2, 0), flag=wx.ALIGN_CENTER_VERTICAL, border=10)
        custom_choice = [u"ARATEK", u"fangzheng", u"huantian", u"mantra", u"MIAXIS", u"new", u"OXi", u"shenzhou", u"Thales", u"win7"]
        self.choiceCustom = wx.Choice(self, wx.ID_ANY, wx.DefaultPosition, wx.Size(80, 25), custom_choice, 0)
        self.choiceCustom.SetSelection(0)
        self.choiceCustom.Bind(wx.EVT_CHOICE, self.custom_choice)
        grid_sizer.Add(self.choiceCustom, pos=(2, 1), flag=wx.EXPAND|wx.ALL, border=10)

          #Win dir
        grid_sizer.Add(wx.StaticText(self, label="Win Dir"), pos=(3, 0), flag=wx.ALIGN_CENTER_VERTICAL, border=10)
        self.txt_win = wx.TextCtrl(self, size = (200, -1))
        grid_sizer.Add(self.txt_win, pos=(3, 1), flag=wx.EXPAND|wx.ALL, border=10)

          #Android dir
        grid_sizer.Add(wx.StaticText(self, label="Anroid Dir"), pos=(4, 0), flag=wx.ALIGN_CENTER_VERTICAL, border=10)
        self.txt_android = wx.TextCtrl(self, size = (200, -1))
        grid_sizer.Add(self.txt_android, pos=(4, 1), flag=wx.EXPAND|wx.ALL, border=10)
     
     
        grider_det = wx.GridSizer(0, 3, 0, 9) 
        self.btn_API = wx.Button(self, label="Gen API")
        self.btn_SDK = wx.Button(self, label="Gen SDK")
        self.btn_Ver = wx.Button(self, label="Gen Ver.")
        self.btn_API.Bind(wx.EVT_BUTTON, self.genAipDoc)
        self.btn_SDK.Bind(wx.EVT_BUTTON, self.genSDK)
        self.btn_Ver.Bind(wx.EVT_BUTTON, self.genVer)

        grider_det.Add(self.btn_API, 0, wx.ALL | wx.EXPAND, 5)
        grider_det.Add(self.btn_SDK, 0, wx.ALL | wx.EXPAND, 5)
        grider_det.Add(self.btn_Ver, 0, wx.ALL | wx.EXPAND, 5)
        grid_sizer.Add(grider_det, pos=(5, 1), flag=wx.EXPAND|wx.ALL, border=10)

        # grid_sizer.Add(self.btn_API, pos=(5, 0), flag=wx.EXPAND|wx.ALL, border=10)
        # grid_sizer.Add(self.btn_SDK, pos=(5, 1), flag=wx.EXPAND|wx.ALL, border=10)
        # grid_sizer.Add(self.btn_Ver, pos=(5, 2), flag=wx.EXPAND|wx.ALL, border=10)
    
        # 添加更多控件
        grid_sizer.Add(wx.StaticText(self, label="LOG"), pos=(6, 0), flag=wx.ALIGN_CENTER_VERTICAL, border=10)
        self.text_ctrl = wx.TextCtrl(self, size=(400,300), style=wx.TE_MULTILINE)
        grid_sizer.Add(self.text_ctrl, pos=(6, 1), flag=wx.EXPAND|wx.ALL, border=10)

       

        # 让控件跟随窗口拉伸
        grid_sizer.AddGrowableCol(1)  # 允许第二列拉伸
        grid_sizer.AddGrowableRow(2)  # 允许第三行拉伸
        
        # 将 grid_sizer 添加到 outer_sizer，并设置顶部边距
        outer_sizer.Add(grid_sizer, flag=wx.EXPAND | wx.ALL, border=10)  # 设置顶部、底部、左侧和右侧边距
        # 设置外层 sizer
        self.SetSizer(outer_sizer)
        self.SetSize((600, 400))  # 设置初始大小

        outer_sizer.Fit(self)  # 调整窗口大小以适应控件

        self.Layout()

    def project_choice(self, event):
        self.selectPj = event.GetString()
        if self.selectPj == "G2":
            self.dirPj = "D:\git\oxi\g2\g2020\G2020SDK"
            self.dirWIN = "D:\git\oxi\g2\g2020\G2020WinDemo"
            self.dirAndroid = "D:\git\oxi\g2\g2020\G2020Android"
            self.dirTarget = "D:\G2SDKLib\doc"
        if self.selectPj == "G4":
            self.dirPj = "D:\git\oxi\OXiScan"
            self.dirWIN = "D:\git\oxi\g4\G45Win"
            self.dirAndroid = "D:\git\oxi\g4\G45Android"
            self.dirTarget = "D:\G4SDKLib\doc"
        if self.selectPj == "G6":
            self.dirPj = "D:\git\oxi\g6\FAP6010_"
            self.dirWIN = "D:\git\oxi\g6\g6010WinDemo_"
            self.dirAndroid = "D:\git\oxi\g6\G6010Android_"
            self.dirTarget = "D:\G6SDKLib\doc"
        if self.selectPj == "G7":
            self.dirPj = "D:\git\oxi\OXiScan"
            self.dirWIN = "D:\git\oxi\g7\G7010WinDemo"
            self.dirAndroid = "D:\git\oxi\g7\G7010Android"
            self.dirTarget = "D:\G7SDKLib\doc"

        self.txt_pj.Clear()
        self.txt_pj.AppendText(self.dirPj)
        self.txt_win.Clear()
        self.txt_win.AppendText(self.dirWIN)
        self.txt_android.Clear()
        self.txt_android.AppendText(self.dirAndroid)

        detect_sym = u"项目 :\t{}\n".format(self.selectPj)
        self.text_ctrl.AppendText(detect_sym)

    def custom_choice(self, event):
        self.selectCustom = event.GetString()
        if self.selectPj == "G6":
            self.dirPj = u"D:\git\oxi\g6\FAP6010_{}".format(self.selectCustom)
            self.dirWIN = u"D:\git\oxi\g6\g6010WinDemo_{}".format(self.selectCustom)
            self.dirAndroid = u"D:\git\oxi\g6\G6010Android_{}".format(self.selectCustom)
            self.dirTarget = u"D:\G6SDKLib\{}\G6SDKv".format(self.selectCustom)
            self.txt_pj.Clear()
            self.txt_pj.AppendText(self.dirPj)
            self.txt_win.Clear()
            self.txt_win.AppendText(self.dirWIN)
            self.txt_android.Clear()
            self.txt_android.AppendText(self.dirAndroid)
            detect_sym = u"客户 :\t{}\n".format(self.selectCustom)
            self.text_ctrl.AppendText(detect_sym)

    def genAipDoc(self, event):
        detect_sym = u"gen API :\t sourceDir: {0} \n\t targetDir: {1}\n".format(self.dirPj, self.dirTarget)
        self.text_ctrl.AppendText(detect_sym)
        createSDKAPI(self.dirPj, self.dirTarget)

    def genSDK(self, event):
        detect_sym = event.GetString()
        detect_sym = u"当前状态为 :\t{}\n".format(detect_sym)
        self.text_ctrl.AppendText(detect_sym)
        
    def genVer(self, event):
        detect_sym = u"gen version start\n"
        self.text_ctrl.AppendText(detect_sym)
        createVersion(self.dirPj, self.dirWIN, self.dirAndroid, self.dirTarget)
        detect_sym = u"gen version down\n"
        self.text_ctrl.AppendText(detect_sym)
        


class MyApp(wx.App): 
    def OnInit(self):
        self.frame = MyFrame(None)  
        self.SetTopWindow(self.frame)
        self.frame.Show(True)
        return True
        
if __name__ == '__main__': 
    app = MyApp()  
    app.MainLoop()  