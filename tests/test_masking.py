import os
import sys
import cv2
import numpy as np
from PIL import Image

# Ensure project modules can be imported
root_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, root_path)

from masking.generate_mask import generate_face_parts_mask as generate_mp_mask
from masking.generate_mask import smooth_mask, dilate_mask
from masking_bisenet.generate_mask_bisenet import generate_bisenet_face_parts_mask as generate_bs_mask

def test_mask_generation():
    # 1. Check if the input image exists
    image_path = "../data/raw_face_data/seed107130.png"
    
    if not os.path.exists(image_path):
        print(f"Error: Could not find test image {image_path}")
        return

    print(f"Reading image: {image_path}")
    img = cv2.imread(image_path)

    # 2. Define the facial parts to test
    test_cases = [
        ["lips"],
        ["nose"],
        ["eyebrows"],
        ["eyes"],
        ["lips", "nose", "eyebrows"] # Combination test
    ]

    # Create directory for test results
    os.makedirs("data/test_results", exist_ok=True)

    for parts in test_cases:
        parts_name = "_".join(parts)
        print(f"Generating mask for [{parts_name}]...")
        
        # Generate mask using MediaPipe
        mp_raw_mask = generate_mp_mask(img, parts=parts)
        mp_d_mask = dilate_mask(smooth_mask(mp_raw_mask), pixels=10)

        # Generate mask using BiSeNet
        try:
            bs_raw_mask = generate_bs_mask(img, parts=parts)
            bs_d_mask = dilate_mask(smooth_mask(bs_raw_mask), pixels=10)
        except FileNotFoundError as e:
            print(f"BiSeNet weights missing, skipping: {e}")
            bs_raw_mask = np.zeros_like(mp_raw_mask)
            bs_d_mask = np.zeros_like(mp_d_mask)

        # 3. Merge results into a comparison preview (Original | MP Raw | BiSeNet Raw | MP Dilated | BiSeNet Dilated)
        # Convert single-channel masks back to 3-channel for stacking
        mp_raw_3ch = cv2.cvtColor(mp_raw_mask, cv2.COLOR_GRAY2BGR)
        mp_d_3ch = cv2.cvtColor(mp_d_mask, cv2.COLOR_GRAY2BGR)
        bs_raw_3ch = cv2.cvtColor(bs_raw_mask, cv2.COLOR_GRAY2BGR)
        bs_d_3ch = cv2.cvtColor(bs_d_mask, cv2.COLOR_GRAY2BGR)
        
        # Scale down the preview images
        scale = 0.5
        h, w = img.shape[:2]
        new_size = (int(w*scale), int(h*scale))
        
        preview_img = cv2.resize(img, new_size)
        preview_mp_raw = cv2.resize(mp_raw_3ch, new_size)
        preview_bs_raw = cv2.resize(bs_raw_3ch, new_size)
        preview_mp_d = cv2.resize(mp_d_3ch, new_size)
        preview_bs_d = cv2.resize(bs_d_3ch, new_size)

        # Add text labels to images
        font = cv2.FONT_HERSHEY_SIMPLEX
        cv2.putText(preview_img, "Original", (10, 30), font, 1, (0, 255, 0), 2)
        cv2.putText(preview_mp_raw, "MP Raw", (10, 30), font, 1, (0, 255, 0), 2)
        cv2.putText(preview_bs_raw, "BiSeNet Raw", (10, 30), font, 1, (0, 255, 0), 2)
        cv2.putText(preview_mp_d, "MP Dilated", (10, 30), font, 1, (0, 255, 0), 2)
        cv2.putText(preview_bs_d, "BiSeNet Dilated", (10, 30), font, 1, (0, 255, 0), 2)

        comparison = np.hstack((preview_img, preview_mp_raw, preview_bs_raw, preview_mp_d, preview_bs_d))
        
        save_path = f"data/test_results/mask_test_{parts_name}_comparison.png"
        cv2.imwrite(save_path, comparison)
        print(f"Saved comparison image to: {save_path}")

    print("\nTest complete! Please check the generated results in the data/test_results folder.")

if __name__ == "__main__":
    test_mask_generation()
