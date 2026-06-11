import cv2
import numpy as np

# 1. 读取图片
img = cv2.imread('E:\\Pictures\\avator.jpg')

# 2. 转换为灰度图
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# 3. 创建掩膜（Mask）：将所有接近白色的像素点变为透明
# 将白色区域（像素值接近255）转为透明
_, mask = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)

# 4. 提取 RGB 通道
b, g, r = cv2.split(img)

# 5. 合并为 RGBA 通道
rgba = [b, g, r, mask]
dst = cv2.merge(rgba, 4)

# 6. 保存为 PNG
cv2.imwrite('E:\\Pictures\\avator_transparent.png', dst)
print("转换完成，已保存为 avator_transparent.png")