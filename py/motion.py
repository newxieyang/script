import cv2
import numpy as np
import time


def apply_soft_edge(img, kernel_size=3):
    # 对 Alpha 通道进行高斯模糊，让边缘更柔和
    img[:, :, 3] = cv2.GaussianBlur(img[:, :, 3], (kernel_size, kernel_size), 0)
    return img

# 1. 加载资源

avatar = cv2.imread('E:/Pictures/avator_transparent.png', cv2.IMREAD_UNCHANGED)
# avatar = cv2.resize(avatar, (100, 100)) # 确保头像大小合适
avatar = cv2.resize(avatar, (100, 100), interpolation=cv2.INTER_CUBIC)
# avatar = apply_soft_edge(avatar)

# 2. 动画逻辑
pos_b = (400, 200)

total_distance = 350
frames = 350
pos_a = (50, 50)
bg_original = np.ones((400, 600, 3), dtype=np.uint8) * 255 # 纯白背景

target_fps = 60
frame_duration = 1.0 / target_fps # 每帧持续时间 16.6ms

for i in range(frames):

    start_time = time.time()
    t = i / (frames - 1)
    print(f"Frame {i}: X={int(round(pos_a[0] + (pos_b[0]-pos_a[0])*t))}")
    # 使用缓动函数：让动画起步和结束时变慢，中间平滑过渡
    ease_t = t * t * (3 - 2 * t)
    
    curr_x = int(round(pos_a[0] + total_distance * ease_t))
    curr_y = int(round(pos_a[1] + (total_distance // 2) * ease_t))
    
    # 复制背景
    frame = bg_original.copy()
    
    # --- 核心叠加逻辑 ---
    h, w = avatar.shape[:2]
    # 获取 Alpha 通道并归一化 (0-1)
    alpha_mask = avatar[:, :, 3] / 255.0
    
    # 简单的区域混合
    for c in range(3):
        frame[curr_y:curr_y+h, curr_x:curr_x+w, c] = (
            alpha_mask * avatar[:, :, c] + 
            (1 - alpha_mask) * frame[curr_y:curr_y+h, curr_x:curr_x+w, c]
        )
    
    cv2.imshow('Moving Avatar', frame)
    elapsed = time.time() - start_time
    wait_time = max(1, int((frame_duration - elapsed) * 1000))
    if cv2.waitKey(30) & 0xFF == ord('q'):
        break

cv2.destroyAllWindows()