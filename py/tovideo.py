import cv2
import numpy as np

width, height = 600, 400
fps = 60
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
video_path = r'E:/Pictures/avatar_animation.mp4'
video = cv2.VideoWriter(video_path, fourcc, fps, (width, height))
video.set(cv2.VIDEOWRITER_PROP_QUALITY, 98)

# 白底背景
bg_original = np.ones((height, width, 3), dtype=np.float32) * 255.0

# 读取透明头像
avatar = cv2.imread(r'E:/Pictures/avator_transparent.png', cv2.IMREAD_UNCHANGED)
avatar = cv2.resize(avatar, (100, 100), interpolation=cv2.INTER_LANCZOS4)
h_ava, w_ava = avatar.shape[:2]

# 分离RGB+Alpha，固定三维shape (H,W,1)
avatar_rgb = avatar[..., :3].astype(np.float32)
alpha = avatar[..., 3:4].astype(np.float32) / 255.0

# 动画参数，全程浮点数，无提前取整
total_distance = 350
frames = 450  # 增加帧数，移动步长更小，更顺滑
start_x, start_y = 50.0, 50.0
vert_ratio = 0.25

for i in range(frames):
    t = i / (frames - 1)
    # 平滑缓动，运动速度变化柔和，减少顿挫感
    ease_t = t * t * (3 - 2 * t)

    # 全程浮点数坐标，不做任何int/round截断
    shift_x = start_x + total_distance * ease_t
    shift_y = start_y + total_distance * vert_ratio * ease_t

    # 平移矩阵：直接浮点数偏移整张头像
    trans = np.array([
        [1.0, 0.0, shift_x],
        [0.0, 1.0, shift_y]
    ], dtype=np.float32)

    # 把头像+Alpha一起投射到画布大小，自动双线性亚像素插值
    rgb_canvas = cv2.warpAffine(
        avatar_rgb, trans, (width, height),
        borderMode=cv2.BORDER_CONSTANT, borderValue=(0,0,0)
    )
    alpha_canvas = cv2.warpAffine(
        alpha, trans, (width, height),
        borderMode=cv2.BORDER_CONSTANT, borderValue=(0.0,)
    )
    # 修复维度：warpAffine单通道会压成2维，手动扩维
    alpha_canvas = np.expand_dims(alpha_canvas, axis=-1)

    # Alpha混合，向量化无循环，无色彩闪烁
    frame = alpha_canvas * rgb_canvas + (1.0 - alpha_canvas) * bg_original
    frame = np.clip(frame, 0, 255).astype(np.uint8)

    video.write(frame)

video.release()
print("无抖动动画视频生成完成")