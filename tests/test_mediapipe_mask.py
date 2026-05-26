import os
import sys
import cv2
import numpy as np
from PIL import Image

root_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, root_path)

import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

# Setup model path
model_path = os.path.join(root_path, "data", "face_landmarker.task")
if not os.path.exists(model_path):
    print("Downloading face_landmarker.task...")
    import urllib.request
    urllib.request.urlretrieve(
        'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
        model_path
    )
    print("✅ Download complete.")

# Initialize detector
options = vision.FaceLandmarkerOptions(
    base_options=python.BaseOptions(model_asset_path=model_path),
    num_faces=1
)
detector = vision.FaceLandmarker.create_from_options(options)

LEFT_BROW  = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46]
RIGHT_BROW = [300, 293, 334, 296, 336, 285, 295, 282, 283, 276]
LEFT_EYE   = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
RIGHT_EYE  = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]

def get_landmarks_new(image_np):
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_np)
    result = detector.detect(mp_image)
    if not result.face_landmarks:
        return None
    return result.face_landmarks[0]

def make_brow_mask_from_landmarks(image_np, padding_ratio=0.5):
    h, w = image_np.shape[:2]
    lm = get_landmarks_new(image_np)
    if lm is None:
        print("Warning: Face landmarks not found!")
        return np.zeros((h, w), dtype=np.uint8)

    brow_mask = np.zeros((h, w), dtype=np.uint8)
    eye_mask  = np.zeros((h, w), dtype=np.uint8)

    # Eyebrows mask
    for brow_idx in [LEFT_BROW, RIGHT_BROW]:
        pts = np.array([[int(lm[i].x * w), int(lm[i].y * h)] for i in brow_idx])
        x_min, y_min = pts.min(axis=0)
        x_max, y_max = pts.max(axis=0)
        brow_w = x_max - x_min
        brow_h = y_max - y_min

        pad_x = int(brow_w * padding_ratio)
        pad_y = int(brow_h * padding_ratio * 2)

        x_min = max(0, x_min - pad_x)
        x_max = min(w, x_max + pad_x)
        y_min = max(0, y_min - pad_y)
        y_max = min(h, y_max + pad_y)

        hull = cv2.convexHull(pts)
        cv2.fillConvexPoly(brow_mask, hull, 255)
        brow_mask[y_min:y_max, x_min:x_max] = cv2.bitwise_or(
            brow_mask[y_min:y_max, x_min:x_max],
            np.full((y_max-y_min, x_max-x_min), 255, dtype=np.uint8)
        )

    # Eyes mask (exclusion area)
    for eye_idx in [LEFT_EYE, RIGHT_EYE]:
        pts = np.array([[int(lm[i].x * w), int(lm[i].y * h)] for i in eye_idx])
        hull = cv2.convexHull(pts)
        cv2.fillConvexPoly(eye_mask, hull, 255)
    
    # Dilate eye mask
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))
    eye_mask = cv2.dilate(eye_mask, k)

    # Remove eyes from eyebrow mask
    final_mask = cv2.bitwise_and(brow_mask, cv2.bitwise_not(eye_mask))
    final_mask = cv2.GaussianBlur(final_mask, (11, 11), 0)
    _, final_mask = cv2.threshold(final_mask, 127, 255, cv2.THRESH_BINARY)

    return final_mask

def run_test():
    img_path = os.path.join(root_path, "data", "actor.jpeg")
    img = cv2.imread(img_path)
    if img is None:
        print(f"Error: actor.jpeg not found at {img_path}")
        return

    # Resize to 512x512
    img_512 = cv2.resize(img, (512, 512))
    
    print("Generating MediaPipe adaptive eyebrow mask...")
    mask = make_brow_mask_from_landmarks(img_512, padding_ratio=0.5)
    
    output_dir = os.path.join(root_path, "tests/data/eyebrow_tests")
    os.makedirs(output_dir, exist_ok=True)
    
    out_mask_path = os.path.join(output_dir, "test_mediapipe_mask.png")
    cv2.imwrite(out_mask_path, mask)
    print(f"✅ Success! Generated mask saved to: {out_mask_path}")
    print(f"Mask active pixel count: {np.sum(mask == 255)}")

if __name__ == "__main__":
    run_test()
