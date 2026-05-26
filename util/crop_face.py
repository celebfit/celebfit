import cv2
import numpy as np

def get_crop_info(mask, image_shape, target_size=512):
    """
    计算以掩码为中心、大小固定为 target_size 的裁切区域。
    """
    h, w = image_shape[:2]
    
    y_indices, x_indices = np.where(mask > 0)
    if len(x_indices) == 0:
        cx, cy = w // 2, h // 2
    else:
        min_x, max_x = np.min(x_indices), np.max(x_indices)
        min_y, max_y = np.min(y_indices), np.max(y_indices)
        cx, cy = (min_x + max_x) // 2, (min_y + max_y) // 2

    x1 = cx - target_size // 2
    y1 = cy - target_size // 2
    
    if x1 < 0: x1 = 0
    if y1 < 0: y1 = 0
    if x1 + target_size > w: x1 = w - target_size
    if y1 + target_size > h: y1 = h - target_size
    
    x1 = max(0, x1)
    y1 = max(0, y1)
    cw = min(target_size, w - x1)
    ch = min(target_size, h - y1)

    return (int(x1), int(y1), int(cw), int(ch))

def get_zoom_crop_info(mask, image_shape, padding_ratio=2.5, min_size=0):
    """
    【特写模式】根据眉毛大小自动缩放裁剪区域。
    padding_ratio: 裁剪区域相对于眉毛包围盒的倍数。
    min_size: 最小裁剪框尺寸，用于保留特写细节并防止过小裁剪。
    """
    h, w = image_shape[:2]
    y_indices, x_indices = np.where(mask > 0)
    
    if len(x_indices) == 0:
        return (0, 0, w, h) # 兜底全图
    
    # 1. 计算眉毛包围盒
    min_x, max_x = np.min(x_indices), np.max(x_indices)
    min_y, max_y = np.min(y_indices), np.max(y_indices)
    bw = max_x - min_x
    bh = max_y - min_y
    
    # 2. 以长边为基准扩展为正方形，并结合 min_size
    side = max(max(bw, bh) * padding_ratio, min_size)
    side = min(side, w, h)
    
    # 3. 确定中心并计算左上角
    cx, cy = (min_x + max_x) // 2, (min_y + max_y) // 2
    x1 = int(cx - side // 2)
    y1 = int(cy - side // 2)
    
    # 4. 边界处理：尽量保持正方形
    x1 = max(0, x1)
    y1 = max(0, y1)
    
    # 如果超出右边界
    if x1 + side > w:
        x1 = max(0, int(w - side))
    # 如果超出下边界
    if y1 + side > h:
        y1 = max(0, int(h - side))
        
    return (x1, y1, int(side), int(side))

def get_actor_face_crop_info(mask, image_shape, padding_ratio=4.0, vertical_offset_ratio=0.08):
    """
    根据“额头中线-双眼下方-太阳穴两侧”的比例计算裁切区域。
    基于眉毛的 bounding box 进行计算，并向下偏移以包含双眼。
    """
    h, w = image_shape[:2]
    y_indices, x_indices = np.where(mask > 0)
    
    if len(x_indices) == 0:
        return (0, 0, w, h) # 兜底全图
        
    min_x, max_x = np.min(x_indices), np.max(x_indices)
    min_y, max_y = np.min(y_indices), np.max(y_indices)
    bw = max_x - min_x
    bh = max_y - min_y
    
    # 太阳穴两侧的宽度通常是眉毛宽度的 4.0 倍左右（对应于包含完整眼眉和眼部区域的方形）
    side = int(bw * padding_ratio)
    side = min(side, w, h)
    
    # 中心点：水平居中，垂直方向向下偏移（以覆盖“双眼下方”并保持“额头中线”在上方）
    cx = (min_x + max_x) // 2
    cy = (min_y + max_y) // 2
    cy_offset = int(bw * vertical_offset_ratio)
    cy_new = cy + cy_offset
    
    x1 = int(cx - side // 2)
    y1 = int(cy_new - side // 2)
    
    # 边界限制与保持正方形
    x1 = max(0, x1)
    y1 = max(0, y1)
    
    if x1 + side > w:
        x1 = max(0, int(w - side))
    if y1 + side > h:
        y1 = max(0, int(h - side))
        
    return (x1, y1, int(side), int(side))

def get_random_actor_face_crop_info(mask, image_shape, min_padding=3.6, max_padding=4.4, max_shift=15):
    """
    用于数据增强的随机裁切版本（针对原人脸图像，匹配“额头中线-双眼下方-太阳穴两侧”）。
    """
    h, w = image_shape[:2]
    y_indices, x_indices = np.where(mask > 0)
    
    if len(x_indices) == 0:
        return (0, 0, w, h)
        
    min_x, max_x = np.min(x_indices), np.max(x_indices)
    min_y, max_y = np.min(y_indices), np.max(y_indices)
    bw = max_x - min_x
    bh = max_y - min_y
    
    padding_ratio = np.random.uniform(min_padding, max_padding)
    side = int(bw * padding_ratio)
    side = min(side, w, h)
    
    cx = (min_x + max_x) // 2
    cy = (min_y + max_y) // 2
    
    # 垂直偏移随机微调：0.06 到 0.10
    vertical_offset_ratio = np.random.uniform(0.06, 0.10)
    cy_offset = int(bw * vertical_offset_ratio)
    cy_new = cy + cy_offset
    
    # 随机中心偏移 (Data Augmentation)
    shift_x = np.random.randint(-max_shift, max_shift + 1)
    shift_y = np.random.randint(-max_shift, max_shift + 1)
    
    cx += shift_x
    cy_new += shift_y
    
    x1 = int(cx - side // 2)
    y1 = int(cy_new - side // 2)
    
    x1 = max(0, x1)
    y1 = max(0, y1)
    
    if x1 + side > w:
        x1 = max(0, int(w - side))
    if y1 + side > h:
        y1 = max(0, int(h - side))
        
    return (x1, y1, int(side), int(side))

def apply_crop(image, crop_info, target_size=512):
    """
    裁切并缩放到 target_size。
    """
    x, y, cw, ch = crop_info
    cropped = image[y:y+ch, x:x+cw]
    
    # 自动缩放到目标尺寸
    if cw != target_size or ch != target_size:
        # 使用 INTER_LANCZOS4 保持高精细纹理
        return cv2.resize(cropped, (target_size, target_size), interpolation=cv2.INTER_LANCZOS4)
    return cropped

def restore_crop(cropped_512, crop_info, orig_shape):
    """
    将缩放后的 512 贴回原图位置（需要先 resize 回去）。
    """
    x, y, cw, ch = crop_info
    
    # 先把生成的图 resize 回原始裁剪大小
    rescaled = cv2.resize(cropped_512, (cw, ch), interpolation=cv2.INTER_LANCZOS4)
    
    if len(orig_shape) == 3:
        full_image = np.zeros((orig_shape[0], orig_shape[1], 3), dtype=np.uint8)
    else:
        full_image = np.zeros((orig_shape[0], orig_shape[1]), dtype=np.uint8)
        
    full_image[y:y+ch, x:x+cw] = rescaled
    return full_image
