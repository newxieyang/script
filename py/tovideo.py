import cv2
import numpy as np

# 1. 视频设置
width, height = 600, 400
fps = 60
fourcc = cv2.VideoWriter_fourcc(*'mp4v') # 定义编码器
video = cv2.VideoWriter('E:/Pictures/avatar_animation.mp4', fourcc, fps, (width, height))

# 2. 资源初始化
bg_original = np.ones((height, width, 3), dtype=np.uint8) * 255
avatar = cv2.imread('E:/Pictures/avator_transparent.png', cv2.IMREAD_UNCHANGED)
avatar = cv2.resize(avatar, (100, 100), interpolation=cv2.INTER_CUBIC)

# 3. 动画参数
total_distance = 350
frames = 350
pos_a = (50, 50)

# 4. 动画循环并写入视频
for i in range(frames):
    t = i / (frames - 1)
    ease_t = t * t * (3 - 2 * t)
    
    curr_x = int(round(pos_a[0] + total_distance * ease_t))
    curr_y = int(round(pos_a[1] + (total_distance // 4) * ease_t)) # 垂直偏移
    
    frame = bg_original.copy()
    
    # Alpha 混合逻辑
    h, w = avatar.shape[:2]
    alpha_mask = avatar[:, :, 3] / 255.0
    for c in range(3):
        frame[curr_y:curr_y+h, curr_x:curr_x+w, c] = (
            alpha_mask * avatar[:, :, c] + 
            (1 - alpha_mask) * frame[curr_y:curr_y+h, curr_x:curr_x+w, c]
        )
    
    # 写入视频帧
    video.write(frame)
    
    # 可选：如果你想看到实时预览，保留下面两行
    # cv2.imshow('Recording', frame)
    # if cv2.waitKey(1) & 0xFF == ord('q'): break

# 5. 释放资源
video.release()
print("视频已生成: avatar_animation.mp4")