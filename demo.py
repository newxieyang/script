import wx 
import cv2 
class App(wx.App): 
    def __init__(self): 
        wx.App.__init__(self) 
        self.frame = wx.Frame(None, title="demoUI") 
        self.panel = wx.Panel(self.frame) 
        # ----------------------- # 新建控件位置变量 # ----------------------- 
        VERTICAL = wx.BoxSizer(wx.VERTICAL) 
        HORIZONTAL = wx.BoxSizer(wx.HORIZONTAL) 
        # ----------------------- # 新建控件 

        self.opare = wx.StaticBoxSizer(wx.StaticBox(self.panel, wx.ID_ANY, "操作栏"), wx.VERTICAL)
        # self.image_op = wx.StaticBoxSizer(wx.StaticBox(self.opare.GetStaticBox(), wx.ID_ANY, "图片操作栏"), wx.HORIZONTAL)
        # self.detect_op = wx.StaticBoxSizer(wx.StaticBox(self.opare.GetStaticBox(), wx.ID_ANY, "检测选择栏"), wx.HORIZONTAL)
        # self.sympol = wx.StaticBoxSizer(wx.StaticBox(self.opare.GetStaticBox(), wx.ID_ANY, "状态栏"), wx.VERTICAL)

        # 图片操作栏 
        grider = wx.GridSizer(2, 3, 0, 9)
        self.btn_project_para = wx.StaticText(self.opare.GetStaticBox(), label="Project")
        project_choice = [u"G2", u"G4", u"G6", u"G7"]
        self.choicePJ = wx.Choice(self.opare.GetStaticBox(), wx.ID_ANY, wx.DefaultPosition, wx.Size(80, 25), project_choice, 0)
        self.choicePJ.SetSelection(0)
        self.choicePJ.Bind(wx.EVT_CHOICE, self.project_choice)
        self.path_project = wx.TextCtrl(self.opare.GetStaticBox(), size=(40, 10))

        self.btn_custom_para = wx.StaticText(self.opare.GetStaticBox(), label="Custom")
        custom_choice = [u"OXi", u"MAinx", u"fangzheng", u"CC"]
        self.choiceCustom = wx.Choice(self.opare.GetStaticBox(), wx.ID_ANY, wx.DefaultPosition, wx.Size(80, 25), custom_choice, 0)
        self.choiceCustom.SetSelection(0)
        self.choiceCustom.Bind(wx.EVT_CHOICE, self.custom_choice)
        self.path_custom = wx.TextCtrl(self.opare.GetStaticBox(), size=(40, 10))


        # btn_open = wx.Button(self.image_op.GetStaticBox(), label="打开文件", size=(10, 10))
        # btn_close = wx.Button(self.image_op.GetStaticBox(), label="关闭文件")
        # 选择 
        grider_det = wx.GridSizer(0, 3, 0, 9) 
        self.btn_API = wx.Button(self.opare.GetStaticBox(), label="Gen API")
        self.btn_SDK = wx.Button(self.opare.GetStaticBox(), label="Gen SDK")
        self.btn_Ver = wx.Button(self.opare.GetStaticBox(), label="Gen Ver.")
        # 参数设置 
        # grider1 = wx.GridSizer(0, 2, 0, 1)
        # self.btn_ret = wx.Button(self.para_op.GetStaticBox(), label="待检索图片文件夹")
        # self.sym_ret = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10))
        # grider2 = wx.GridSizer(0, 3, 0, 2)
        # self.btn_yolo_para = wx.StaticText(self.para_op.GetStaticBox(), label="YOLO权重")
        # self.btn_identity_para = wx.StaticText(self.para_op.GetStaticBox(), label="身份识别权重")
        # self.btn_behav_para = wx.StaticText(self.para_op.GetStaticBox(), label="行为识别权重")
        # self.txt_yolo_para = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10))
        # self.txt_identity_para = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10))
        # self.txt_behav_para = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10))
        # 状态栏 
        self.text_ctrl = wx.TextCtrl(self.opare.GetStaticBox(), wx.ID_ANY, wx.EmptyString, pos=wx.DefaultPosition, size=(200, 250), style=wx.TE_MULTILINE)
        # ----------------------- # 绑定事件 # ----------------------- 
        self.btn_API.Bind(wx.EVT_BUTTON, self.genAipDoc)
        self.btn_SDK.Bind(wx.EVT_BUTTON, self.genSDK)
        self.btn_Ver.Bind(wx.EVT_BUTTON, self.genVer)
        #btn_close.Bind(wx.EVT_BUTTON, sel) 
        # self.choice.Bind(wx.EVT_CHOICE, self.detect_choice)
        # ----------------------- # 控件分布 # ----------------------- 
        # grider.Add(btn_open, 0, wx.ALL | wx.EXPAND, 5)
        # grider.Add(btn_close, 0, wx.ALL | wx.EXPAND, 5)
        grider.Add(self.btn_project_para, 0, wx.ALL | wx.EXPAND, 5)
        grider.Add(self.choicePJ, 0, wx.ALL | wx.EXPAND, 5)
        grider.Add(self.path_project, 0, wx.ALL | wx.EXPAND, 5)

        grider.Add(self.btn_custom_para, 0, wx.ALL | wx.EXPAND, 5)
        grider.Add(self.choiceCustom, 0, wx.ALL | wx.EXPAND, 5)
        grider.Add(self.path_custom, 0, wx.ALL | wx.EXPAND, 5)


        grider_det.Add(self.btn_API, 0, wx.ALL | wx.EXPAND, 5)
        grider_det.Add(self.btn_SDK, 0, wx.ALL | wx.EXPAND, 5)
        grider_det.Add(self.btn_Ver, 0, wx.ALL | wx.EXPAND, 5)

        self.opare.Add(grider, 0, wx.ALL | wx.EXPAND, 5)
        self.opare.Add(grider_det, 0, wx.ALL | wx.EXPAND, 5)
        self.opare.Add(self.text_ctrl, 1, wx.EXPAND, 5)

        # self.opare.Add(self.image_op, 0, wx.ALL | wx.EXPAND, 5)
        # self.opare.Add(self.detect_op, 0, wx.ALL | wx.EXPAND, 5)
        # self.opare.Add(self.para_op, 0, wx.ALL | wx.EXPAND, 5)
        # self.opare.Add(self.sympol, 0, wx.ALL | wx.EXPAND, 5)


        HORIZONTAL.Add(self.opare, 0, wx.ALL | wx.EXPAND, 5) 
        VERTICAL.Add(HORIZONTAL) 
        # ----------------------- # 最终一些乱七八糟的设置 # ----------------------- 
        self.panel.SetSizer(VERTICAL) 
        self.panel.Layout() 
        HORIZONTAL.Fit(self.frame) 
        self.frame.Show() 
        self.frame.Bind(wx.EVT_CLOSE, self.onclose) 

    def genAipDoc(self, event):
        detect_sym = event.GetString()
        detect_sym = u"当前状态为 :\t{}\n".format(detect_sym)
        self.text_ctrl.AppendText(detect_sym)

    def genSDK(self, event):
        detect_sym = event.GetString()
        detect_sym = u"当前状态为 :\t{}\n".format(detect_sym)
        self.text_ctrl.AppendText(detect_sym)
        
    def genVer(self, event):
        detect_sym = event.GetString()
        detect_sym = u"当前状态为 :\t{}\n".format(detect_sym)
        self.text_ctrl.AppendText(detect_sym)
    def project_choice(self, event):
        detect_sym = event.GetString()
        detect_sym = u"当前状态为 :\t{}\n".format(detect_sym)
        self.text_ctrl.AppendText(detect_sym)

    def custom_choice(self, event):
        detect_sym = event.GetString()
        detect_sym = u"当前状态为 :\t{}\n".format(detect_sym)
        self.text_ctrl.AppendText(detect_sym)
    def detect_choice(self, event): 
        detect_sym = event.GetString() 
        detect_sym = u"当前状态为 :\t{}\n".format(detect_sym) 
        self.text_ctrl.AppendText(detect_sym) 
        
    def Show_sym(self, sym): 
        self.text_ctrl.AppendText(sym) 
        
    def onclose(self, evt): 
        dlg = wx.MessageDialog(None, u'确定要关闭本窗口？', u'操作提示', wx.YES_NO | wx.ICON_QUESTION) 
        if (dlg.ShowModal() == wx.ID_YES): 
            self.Destroy() 
        
        
if __name__ == '__main__': 
    app = App() 
    app.MainLoop()