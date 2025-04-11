# !/usr/bin/python
# encoding:utf-8
import os
from docx import Document

from docx.shared import RGBColor
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls
from docx.shared import Inches
from docx.enum.text import WD_PARAGRAPH_ALIGNMENT
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT

G7SRC = "D:/git/oxi/g7/FAP70"
G7target = "D:/G7SDKLib/doc"
G6SRC = "D:/git/oxi/g6/FAP6010"
G6target = "D:/G6SDKLib/doc"
G2SRC = "D:/git/oxi/g2/g2020/G2020SDK"
G2target = "D:/G2SDKLib/doc"

versionName = "/libFAP/include/Version.h"
APIName = "/libFAP/include/ScanAPI.h"
APIName2 = "/libFAP/include/OXiScanAPI.h"

verPathName=""
APIPathName=""
PathName=""
target=""
keyword = "SCAN_API"

custom = ["_ARATEK","_MIAXIS","_win7","_fangzheng","_new","_kejin","_yinken","_huantian","_Thales","_mantra"]

def setSDKPath(sdkname, version):
    global verPathName
    global APIPathName
    global target
    if sdkname in "G7":
        verPathName=G7SRC+versionName
        target= G7target
        if os.path.exists(G7SRC+APIName):
            APIPathName=G7SRC+APIName
        if os.path.exists(G7SRC+APIName2):
            APIPathName=G7SRC+APIName2
    if(sdkname in "G6"):
        target= G6target
        verPathName=G6SRC+custom[version]+versionName
        if os.path.exists(G6SRC+custom[version]+APIName):
            APIPathName=G6SRC+custom[version]+APIName
        if os.path.exists(G6SRC+custom[version]+APIName):
            APIPathName=G6SRC+custom[version]+APIName
    if sdkname in "G2":
        verPathName=G2SRC+versionName
        target= G2target
        if os.path.exists(G2SRC+APIName):
            APIPathName=G2SRC+APIName
        if os.path.exists(G2SRC+APIName2):
            APIPathName=G2SRC+APIName2


# def add_background_color_to_cell(cell, color):
#     # 创建一个形状（矩形）
#     shape = cell.add_shape(MSO_SHAPE_TYPE.RECTANGLE)
#     shape.left = Inches(0)
#     shape.top = Inches(0)
#     shape.width = Inches(cell.width)  # 确保宽度覆盖整个单元格
#     shape.height = Inches(cell.height)  # 确保高度覆盖整个单元格
    
#     # 设置形状的填充颜色
#     shape.fill.solid()
#     shape.fill.fore_color.rgb = RGBColor(*color)  # color should be a tuple of RGB values (e.g., (255, 0, 0) for red)
 

# def add_background_color_to_cell(cell, color):
#     # 在单元格中添加一个段落，然后设置其背景色
#     para = cell.add_paragraph()
#     run = para.add_run(' ')  # 添加一个运行并给它一个空格字符，以便可以设置背景色
#     run._element.rPr.shd = {'fill': color, 'color': 'auto'}  # 设置背景色

def set_cell_background(cell, colorstr):
    shading_elm = parse_xml(r'<w:shd {} w:fill="{color_value}"/>'.format(nsdecls('w'), color_value=colorstr))
    cell._tc.get_or_add_tcPr().append(shading_elm)


def readVer():
    f = open(file=verPathName, encoding="utf-8")
    verName = ""
    for line in f:
        if "#define OXISCAN_VERSION_MAJOR" in line:
            verName += line.split(" ")[2].replace('\n', '') + "."
        if "#define OXISCAN_VERSION_MINOR" in line:
            verName += line.split(" ")[2].replace('\n', '') + "."
        if "#define OXISCAN_VERSION_PATCH" in line:
            verName += line.split(" ")[2].replace('\n', '') + "."
        if "#define OXISCAN_VERSION_BUILD" in line:
            verName += line.split(" ")[2].replace('\n', '')

    print(verName)
    return verName


def readAPI():
    f = open(file=APIPathName, encoding="utf-8")
    liner = []
    for line in f:
        if keyword in line:
            if "HANDLE" in line:
                liner.append(line)
    return liner


def getFuntionName(funStr):
    str = funStr.split("(")[0]
    str = str.replace("  ", " ")
    return str.split(" ")[2]


def getFuntionString(funStr):
    return funStr.replace("OXISCAN_API ", "").strip()



def readFunInfo(funName):

    f = open(file=APIPathName, encoding="utf-8")
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
            break
                
    return liner


def writeRecord(doc):
    doc.add_heading("1. Record of Revision", 1)
    table = doc.add_table(rows=1, cols=4, style="Table Grid")
    table.rows[0].height = Inches(0.3)
    hdr_cells = table.rows[0].cells
    hdr_cells[0].text = 'Rev'
    hdr_cells[1].text = 'Issue Date'
    hdr_cells[2].text = 'Description'
    hdr_cells[3].text = 'Editor'
    hdr_cells[0].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    hdr_cells[1].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    hdr_cells[2].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    hdr_cells[3].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER

    for cell in table.rows[0].cells:
        set_cell_background(cell, 'c0c0c0')
        cell.height = Inches(1.5)


    for index in range(4):
        row_cells = table.add_row().cells
        table.rows[index+1].height = Inches(0.3)
        row_cells[0].width = Inches(2)
        row_cells[1].width = Inches(1)
        row_cells[2].width = Inches(4)
        row_cells[3].width = Inches(2)

        row_cells[0].text = str(index)
        row_cells[1].text = "2025-04-03"
        row_cells[2].text = "ok"
        row_cells[3].text = "Yang Xie"
        row_cells[0].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        row_cells[1].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        row_cells[2].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        row_cells[3].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    
    doc.add_page_break()


def writeDocx(verName, liner):
    doc = Document()
    # doc.add_paragraph('hello world')
    doc.add_heading('Fingerprint Scanner SDK (ISO)', 0)
    doc.add_heading('User Manual', 0)
    doc.add_heading('V'+verName, 0)

    doc.add_heading('Shanghai OXi Technology Company Ltd.', 4)
    doc.add_page_break()

    writeRecord(doc)

    doc.add_heading("2. What is the Fingerprint SDK (ISO)", 1)
    doc.add_paragraph(" Fingerprint SDK (ISO) is a fingerprint authentication software development tool which is designed for the application developers to apply the fingerprint recognition functions in developing of fingerprint recognition programs based on fingerprint international standard.")
    doc.add_page_break()

    doc.add_heading("3. API References", 1)
    doc.add_paragraph("The library-calling interface includes the following functions: ")


    # color = RGBColor(230, 230, 230)  # 黄色背景
 

    # len = len(liner)
    table = doc.add_table(rows=1, cols=3, style="Table Grid")
    hdr_cells = table.rows[0].cells
    table.rows[0].height = Inches(0.3)
    hdr_cells[0].text = 'No'
    hdr_cells[1].text = 'function'
    hdr_cells[2].text = 'explain'
    hdr_cells[0].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    hdr_cells[1].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    hdr_cells[2].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER

    for cell in table.rows[0].cells:
        set_cell_background(cell, 'c0c0c0')

    for index in range(len(liner)):
        row_cells = table.add_row().cells
        table.rows[index+1].height = Inches(0.3)
        row_cells[0].text = str(index)
        row_cells[0].width = Inches(2)
        row_cells[1].width = Inches(4)
        row_cells[2].width = Inches(2)
        row_cells[1].text = getFuntionName(liner[index])
        row_cells[2].text = "ok"
        row_cells[0].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        row_cells[1].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        row_cells[2].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER



   #document.add_paragraph('first item in unordered list', style='List Bullet')
    for index in range(len(liner)):
        funName = getFuntionName(liner[index])
        doc.add_heading(str(index+1) + "." + funName, 3)

        #### Signature
        sin = doc.add_paragraph()
        run = sin.add_run("Signature")
        run.font.bold = True
        run.font.italic = True
       
        table2 = doc.add_table(rows=1, cols=2,style="Table Grid")
        # cols = table2.columns
        # cols[0].width = Pt(42)
        # cols[1].width = Pt(42*5)

        table2.rows[0].height = Inches(0.4)
        hdr_cells = table2.rows[0].cells
        hdr_cells[0].width = Inches(1.2)
        set_cell_background(hdr_cells[0], 'c9c9c9')
        # paragraph = hdr_cells[0].paragraphs[0]
        # paragraph.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER
        # 设置段落的垂直对齐方式为居中
        hdr_cells[0].text = "Method"
        hdr_cells[0].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        hdr_cells[0].paragraphs[0].runs[0].bold = True
        hdr_cells[1].text = getFuntionString(liner[index])
        hdr_cells[1].width = Inches(8)
        hdr_cells[1].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER

##########
        
        funInfo = readFunInfo(funName)
  #### Description
        sin = doc.add_paragraph()
        sin.add_run("\n")
        run = sin.add_run("Description")
        run.font.bold = True
        run.font.italic = True
        # sin.add_run("\n")
       

        des = doc.add_paragraph()
        for desc in funInfo:
            if "brief" in desc:
                # msg = des.add_run(desc.split("brief")[1].strip()
                run = des.add_run("  " + desc.split("brief")[1].strip() + "\n")
                break
        des.add_run("  Result\n")
        havaReturn = False
        for desc in funInfo:
            if "return" in desc:
                havaReturn = True
                continue
            if havaReturn:
                if "OXISCAN_API" not in desc:
                     des.add_run(desc.replace("///", ""))
                     des.add_run("\n")



####   Parameter
        sin = doc.add_paragraph()
        run = sin.add_run("Parameter")
        run.font.bold = True
        run.font.italic = True
        para = []
        for desc in funInfo:
            if "param" in desc:
                info = desc.split("param")[1].strip()
                para.append(info)
                print(info)
        
        tableLen = len(para) + 1
        if(tableLen > 1):
            table3 = doc.add_table(rows=1, cols=2,style="Table Grid")
            table3.rows[0].height = Inches(0.3)
            hdr_cells = table3.rows[0].cells
            hdr_cells[0].text = "Parameter"
            hdr_cells[0].width = Inches(2)
            hdr_cells[0].paragraphs[0].runs[0].bold = True
            hdr_cells[1].text = "Description"
            hdr_cells[1].width = Inches(6)
            hdr_cells[0].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            hdr_cells[1].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_background(hdr_cells[0], 'c9c9c9')
            set_cell_background(hdr_cells[1], 'c9c9c9')

            for index in range(len(para)):
                cs = para[index].split("[")
                row_cells = table3.add_row().cells
                table3.rows[index+1].height = Inches(0.3)
                row_cells[0].text = cs[0]
                row_cells[0].width = Inches(2)
                row_cells[1].width = Inches(6)
                row_cells[1].text = para[index].replace(cs[0], "").strip()
                row_cells[0].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
                row_cells[1].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


    doc.save(target+ '/Fingerprint Scanner SDK (ISO)v '+verName+'.docx')
    


if __name__ == '__main__':
    setSDKPath("G2", 9)
    print(APIPathName)
    print(verPathName)
    print("-----------------------------")
    verName = readVer()
    liner = readAPI()
    writeDocx(verName, liner)
    print(target)