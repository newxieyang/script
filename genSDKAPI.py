# !/usr/bin/python
# encoding:utf-8
import os
import re
from docx import Document

from docx.shared import RGBColor
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls
from docx.shared import Inches
from docx.enum.text import WD_PARAGRAPH_ALIGNMENT
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.shared import Pt
from docx.oxml import OxmlElement

from fileUtils import *


# keyword = "SCAN_API"
keyword = "OXISCAN_EXPORT"
# keyword = "OXISCAN_API"



def set_cell_background(cell, colorstr):
    shading_elm = parse_xml(r'<w:shd {} w:fill="{color_value}"/>'.format(nsdecls('w'), color_value=colorstr))
    cell._tc.get_or_add_tcPr().append(shading_elm)






def readAPI(APIpathName):
    f = open(file=APIpathName, encoding="utf-8")
    liner = []
    for line in f:
        if keyword in line:
            if "OXiScan_" in line:
                liner.append(line)
    return liner


def getFuntionName(funStr):
    # str = funStr.split("(")[0]
    # str = str.replace("  ", " ")
    pattern = re.compile(r'\b(?:[a-zA-Z_][a-zA-Z0-9_]*::)?(?:template\s*<.*?>\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*(?:const)?\s*(?:throw\s*\([^)]*\))?\s*;\s*|\b(?:[a-zA-Z_][a-zA-Z0-9_]*::)?(?:template\s*<.*?>\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*(?:const)?\s*(?:\{|\s*throw\s*\([^)]*\)\s*;\s*)', re.MULTILINE)

    match = pattern.search(funStr)
    if match:
        # 由于使用了多个捕获组，我们需要检查哪个组匹配到了内容
        function_name = next((group for group in match.groups() if group), None)
        print("第一个匹配到的函数名是:", function_name)
        return function_name
    else:
        print("没有找到匹配项")

    # print("匹配到的函数名有:", function_names)

    return function_names


def getFuntionString(funStr):
    return funStr.replace(keyword +" ", "").strip()



def readFunInfo(funName, APIPathName):

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
           
        if funName.lower() in line.lower():
            break
                
    return liner


def writeRecord(doc):
    doc.add_heading("1. Record of Revision", 1)
    table = doc.add_table(rows=1, cols=4, style="Table Grid")
    
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


def writeDesc(doc):
    doc.add_heading("2. What is the Fingerprint SDK (ISO)", 1)
    paragraph = doc.add_paragraph()
    run = paragraph.add_run("    Fingerprint SDK (ISO)")
    run.bold = True
    run.font.size = Pt(9)  # 重置字体大小（如果需要）
    run.font.name = "Malgun Gothic"
    run = paragraph.add_run(" is a fingerprint authentication software development tool which is designed for the application developers to apply the fingerprint recognition functions in developing of fingerprint recognition programs based on fingerprint international standard.")
    run.font.name = "Malgun Gothic"
    run.font.size = Pt(9) 


    doc.add_heading("Supported Fingerprint Sensor", 2)
    add_ordered_list_item(doc, "Optical fingerprint sensor(G4 G6 G7)")


    doc.add_heading("SDK Features", 2)
    add_ordered_list_item(doc, "Includes FBI-certified, high-performance WSQ fingerprint image compression")
    add_ordered_list_item(doc, "APIs to develop applications to read, write, edit and view ISO/NIST-compliant biometric data")
    add_ordered_list_item(doc, "Run-time applications and demos with source code")
    add_ordered_list_item(doc, "Single API to create both types of structured data (binary and XML)")
    add_ordered_list_item(doc, "C++, .NET, and JNI versions available")
    add_ordered_list_item(doc, "Fully featured C Language API")
    add_ordered_list_item(doc, "C#/.NET wrappers")
    add_ordered_list_item(doc, "Example programs with source")
    add_ordered_list_item(doc, "Support for – Java Native Interface – Microsoft Windows – Linux – and Android")
  

    doc.add_heading("Support for", 2)
    add_ordered_list_item(doc, "Java Native Interface")
    add_ordered_list_item(doc, "Microsoft Windows")
    add_ordered_list_item(doc, "Linux")
    add_ordered_list_item(doc, "Android")

    doc.add_heading("Supported Communication Interface", 2)
    add_ordered_list_item(doc, "USB 1.0, 1.1 and 2.0 (Full Speed) specifications")
    doc.add_page_break()

def writeDocx(verName, liner, target, APIPathName):
    doc = Document()
    # doc.add_paragraph('hello world')
    heading = doc.add_heading('Fingerprint Scanner SDK (ISO)', 0)
    paragraph = heading._element
    paragraph.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER

    heading = doc.add_heading('User Manual', 0)
    paragraph = heading._element
    paragraph.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER

    heading = doc.add_heading('V'+verName, 0)
    paragraph = heading._element
    paragraph.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER

    # doc.add_paragraph("\n\n\n\n\n\n\n\n\n\n\n")
    for index in range(17):
        doc.add_paragraph("")
    # heading = doc.add_heading('Shanghai OXi Technology Company Ltd.', 4)
    paragraph = doc.add_paragraph()
    run = paragraph.add_run("Shanghai OXi Technology Company Ltd.")
   
    run.font.size = Pt(13)  # 重置字体大小（如果需要）
    run.font.name = "Malgun Gothic"
    paragraph.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER
    doc.add_page_break()

    writeRecord(doc)

    writeDesc(doc)

    # API References
    doc.add_heading("3. API References", 1)
    doc.add_paragraph("The library-calling interface includes the following functions: ")

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
        print(funName)
        doc.add_heading(str(index+1) + "." + funName, 2)

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
        
        funInfo = readFunInfo(funName, APIPathName)
  #### Description
        sin = doc.add_paragraph()
        sin.add_run("\n")
        run = sin.add_run("Description")
        run.font.bold = True
        run.font.italic = True
        sin.add_run("\n")
       

        # des = doc.add_paragraph()
        for desc in funInfo:
            if "brief" in desc:
                # msg = des.add_run(desc.split("brief")[1].strip()
                run = sin.add_run("      " + desc.split("brief")[1].strip() + "\n")
                break

        res = doc.add_paragraph()
        run = res.add_run("Result")
        res.add_run("\n")
        run.font.bold = True
        run.font.italic = True
        havaReturn = False
        for desc in funInfo:
            if "return" in desc:
                havaReturn = True
                continue
            if havaReturn:
                if keyword not in desc:
                     res.add_run(desc.replace("///", "").replace("\t","    "))
                     res.add_run("\n")



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

        sin = doc.add_paragraph()
        sin.add_run("\n")

    doc.save(target+ '/Fingerprint Scanner SDK (ISO)v '+verName+'.docx')
    



 # 添加有序列表项的函数

def add_ordered_list_item(doc, text):
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_PARAGRAPH_ALIGNMENT.LEFT
    
    # p = paragraph._element
    # line_spacing = OxmlElement('w:spacing')
    # line_spacing.set('w:line', '120')
    # line_spacing.set('w:lineRule', 'exact')
    # p.get_or_add_pPr().append(line_spacing)

    run = paragraph.add_run(text)
    run.font.size = Pt(9)  # 重置字体大小（如果需要）
    run.font.name = "Malgun Gothic"
    # paragraph.style = "‌List Bullet‌"
    # 更新编号
    



def createSDKAPI(pjDir, verDir, targetDir):
    if not pjDir == "":
        print(pjDir)
        buildName = readVer(verDir)
        print("-----------------------------")
        APIFilePath = findFilePathNameByKeyWord(pjDir, "Api") 
        # APIFilePath = findFilePathNameByKeyWord(pjDir, "OXiScan_Api") 
        if APIFilePath is None:
             print("APIFilePath is null")
        else:
            print(APIFilePath)
            liner = readAPI(APIFilePath)
            
            print(targetDir)
            writeDocx(buildName, liner, targetDir, APIFilePath)


if __name__ == '__main__':
    # test()
    # pjPathName = setSDKPathName(2, 8)
    # target = SDKTargetSer[2]
    # createSDKAPI("D:\git\oxi\g6\FAP6010_Thales", "d:/0")
    # createSDKAPI("D:\\git\\oxi\\g6\\FAP6010_ARATEK", "d:/0")
    print("begin genSDK")
    createSDKAPI("D:\\git\\oxi\\OXiScan\\scanapi", "D:\\git\\oxi\\OXiScan\\base", "D:\\GSerSDKLib\\doc")
    # createSDKAPI("D:\\git\\oxi\\OXiScan\\dev\\fap70", "D:\\G7SDKLib\\doc")
    
   