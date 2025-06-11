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
        # # ----------------------- 
        image = wx.EmptyImage(500, 500) 
        self.image_sys = wx.StaticBoxSizer(wx.StaticBox(self.panel, wx.ID_ANY, "检测结果与实时图像"), wx.VERTICAL) 
        self.live_image = wx.StaticBoxSizer(wx.StaticBox(self.image_sys.GetStaticBox(), wx.ID_ANY, "实时图像"), wx.VERTICAL) 
        self.txt_image = wx.StaticBoxSizer(wx.StaticBox(self.image_sys.GetStaticBox(), wx.ID_ANY, "检测结果"), wx.HORIZONTAL) 
        self.txt = wx.StaticText(self.txt_image.GetStaticBox(), size=(10, 10)) 
        self.image = wx.StaticBitmap(self.live_image.GetStaticBox(), wx.ID_ANY, wx.BitmapFromImage(image)) 
        self.opare = wx.StaticBoxSizer(wx.StaticBox(self.panel, wx.ID_ANY, "操作栏"), wx.VERTICAL) 
        self.image_op = wx.StaticBoxSizer(wx.StaticBox(self.opare.GetStaticBox(), wx.ID_ANY, "图片操作栏"), wx.HORIZONTAL) 
        self.detect_op = wx.StaticBoxSizer(wx.StaticBox(self.opare.GetStaticBox(), wx.ID_ANY, "检测选择栏"), wx.HORIZONTAL) 
        self.para_op = wx.StaticBoxSizer(wx.StaticBox(self.opare.GetStaticBox(), wx.ID_ANY, "参数设置栏"), wx.VERTICAL) 
        self.sympol = wx.StaticBoxSizer(wx.StaticBox(self.opare.GetStaticBox(), wx.ID_ANY, "状态栏"), wx.VERTICAL) 
        # 图片操作栏 
        grider = wx.GridSizer(0, 2, 0, 9) 
        btn_open = wx.Button(self.image_op.GetStaticBox(), label="打开文件", size=(10, 10)) 
        btn_close = wx.Button(self.image_op.GetStaticBox(), label="关闭文件") 
        # 选择 
        grider_det = wx.GridSizer(0, 3, 0, 9) 
        detect_choice = [u"YOLO检测", u"身份检测", u"关键点检测", u"行为检测"] 
        self.choice = wx.Choice(self.detect_op.GetStaticBox(), wx.ID_ANY, wx.DefaultPosition, wx.Size(80, 25), detect_choice, 0) 
        self.choice.SetSelection(0) 
        self.btn_det = wx.Button(self.detect_op.GetStaticBox(), label="开始检测") 
        self.btn_cancel_det = wx.Button(self.detect_op.GetStaticBox(), label="取消检测") 
        # 参数设置 
        grider1 = wx.GridSizer(0, 2, 0, 1) 
        self.btn_ret = wx.Button(self.para_op.GetStaticBox(), label="待检索图片文件夹") 
        self.sym_ret = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10)) 
        grider2 = wx.GridSizer(0, 3, 0, 2) 
        self.btn_yolo_para = wx.StaticText(self.para_op.GetStaticBox(), label="YOLO权重") 
        self.btn_identity_para = wx.StaticText(self.para_op.GetStaticBox(), label="身份识别权重") 
        self.btn_behav_para = wx.StaticText(self.para_op.GetStaticBox(), label="行为识别权重") 
        self.txt_yolo_para = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10)) 
        self.txt_identity_para = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10)) 
        self.txt_behav_para = wx.TextCtrl(self.para_op.GetStaticBox(), size=(10, 10)) 
        # 状态栏 
        self.text_ctrl = wx.TextCtrl(self.sympol.GetStaticBox(), wx.ID_ANY, wx.EmptyString, pos=wx.DefaultPosition, size=(200, 250), style=wx.TE_MULTILINE) 
        # ----------------------- # 绑定事件 # ----------------------- 
        btn_open.Bind(wx.EVT_BUTTON, self.openfile) 
        #self.Bind(wx.EVT_BUTTON, self.opendir, self.btn_ret) 
        self.btn_ret.Bind(wx.EVT_BUTTON, self.opendir) 
        #btn_close.Bind(wx.EVT_BUTTON, sel) 
        self.choice.Bind(wx.EVT_CHOICE, self.detect_choice) 
        # ----------------------- # 控件分布 # ----------------------- 
        grider.Add(btn_open, 0, wx.ALL | wx.EXPAND, 5) 
        grider.Add(btn_close, 0, wx.ALL | wx.EXPAND, 5) 
        grider1.Add(self.btn_ret, 0, wx.ALL | wx.EXPAND, 5) 
        grider1.Add(self.sym_ret, 0, wx.ALL | wx.EXPAND, 5) 
        grider2.Add(self.btn_yolo_para, 0, wx.ALL | wx.EXPAND, 5) 
        grider2.Add(self.btn_identity_para, 0, wx.ALL | wx.EXPAND, 5) 
        grider2.Add(self.btn_behav_para, 0, wx.ALL | wx.EXPAND, 5) 
        grider2.Add(self.txt_yolo_para, 0, wx.ALL | wx.EXPAND, 5) 
        grider2.Add(self.txt_identity_para, 0, wx.ALL | wx.EXPAND, 5) 
        grider2.Add(self.txt_behav_para, 0, wx.ALL | wx.EXPAND, 5) 
        grider_det.Add(self.choice, 0, wx.ALL | wx.EXPAND, 5) 
        grider_det.Add(self.btn_det, 0, wx.ALL | wx.EXPAND, 5) 
        grider_det.Add(self.btn_cancel_det, 0, wx.ALL | wx.EXPAND, 5) 
        self.sympol.Add(self.text_ctrl, 1, wx.EXPAND, 5) 
        self.image_op.Add(grider, 0, wx.ALL | wx.EXPAND, 5) 
        self.detect_op.Add(grider_det, 0, wx.ALL | wx.EXPAND, 5) 
        self.para_op.Add(grider1, 0, wx.ALL | wx.EXPAND, 5) 
        self.para_op.Add(grider2, 0, wx.ALL | wx.EXPAND, 5) 
        self.live_image.Add(self.image, 0, wx.ALL | wx.EXPAND, 5) 
        self.txt_image.Add(self.txt, 0, wx.ALL | wx.EXPAND, 5) 
        self.opare.Add(self.image_op, 0, wx.ALL | wx.EXPAND, 5) 
        self.opare.Add(self.detect_op, 0, wx.ALL | wx.EXPAND, 5) 
        self.opare.Add(self.para_op, 0, wx.ALL | wx.EXPAND, 5) 
        self.opare.Add(self.sympol, 0, wx.ALL | wx.EXPAND, 5) 
        self.image_sys.Add(self.live_image, 0, wx.ALL | wx.EXPAND, 5) 
        self.image_sys.Add(self.txt_image, 0, wx.ALL | wx.EXPAND, 5) 
        HORIZONTAL.Add(self.image_sys, 0, wx.ALL | wx.EXPAND, 5) 
        HORIZONTAL.Add(self.opare, 0, wx.ALL | wx.EXPAND, 5) 
        VERTICAL.Add(HORIZONTAL) 
        # ----------------------- # 最终一些乱七八糟的设置 # ----------------------- 
        self.panel.SetSizer(VERTICAL) 
        self.panel.Layout() 
        HORIZONTAL.Fit(self.frame) 
        self.frame.Show() 
        self.frame.Bind(wx.EVT_CLOSE, self.onclose) 

    def openfile(self, event): 
        wildcard = "JPEG files (*.jpg) | *.jpg" 
        dialog = wx.FileDialog(None, "choose a file", wildcard=wildcard, style=wx.FD_OPEN) 
        if dialog.ShowModal() == wx.ID_OK: 
            self.text_ctrl.SetValue(dialog.GetPath() + '\n') 
        dialog.Destroy() 

    def opendir(self, event): 
        wildcard = wx.DirDialog(None, "选择文件夹", style=wx.DD_DEFAULT_STYLE) 
        if wildcard.ShowModal() == wx.ID_OK: 
            self.sym_ret.SetValue(wildcard.GetPath()) 
        wildcard.Destroy() 
        
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