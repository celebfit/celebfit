from __future__ import annotations

"""
MediaPipe-based mask generation for BrushNet inpainting.

Supports multiple segmentation modes:
  - Selfie segmentation (person / background separation)
  - Face mesh segmentation (face region only)
  - General image segmentation (multi-class: person, animal, etc.)

Output masks are saved as binary images compatible with BrushNet's
expected mask format (white = inpaint region, black = keep).

Usage examples:
  # Selfie (person) mask
  python generate_mask.py --input photo.jpg --output mask.jpg --mode selfie

  # Face-only mask
  python generate_mask.py --input photo.jpg --output mask.jpg --mode face

  # General segmentation (specify category)
  python generate_mask.py --input photo.jpg --output mask.jpg --mode category --category person

  # Invert mask (mask everything EXCEPT the detected region)
  python generate_mask.py --input photo.jpg --output mask.jpg --mode selfie --invert

  # Adjust mask dilation (pixels) for a larger mask boundary
  python generate_mask.py --input photo.jpg --output mask.jpg --mode selfie --dilate 15

  # Batch process a directory
  python generate_mask.py --input ./images/ --output ./masks/ --mode selfie
"""

import argparse
import os
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# Model download URL constants
# ---------------------------------------------------------------------------
_MODEL_URLS = {
    "selfie_segmenter": "https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite",
    "selfie_multiclass": "https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_multiclass_256x256/float16/latest/selfie_multiclass_256x256.tflite",
    "deeplab_v3": "https://storage.googleapis.com/mediapipe-models/image_segmenter/deeplab_v3/float32/latest/deeplab_v3.tflite",
    "face_landmarker": "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task",
}

# Selfie multiclass category indices
SELFIE_MULTICLASS_CATEGORIES = {
    "background": 0,
    "hair": 1,
    "body_skin": 2,
    "face_skin": 3,
    "clothes": 4,
    "others": 5,
}

# Fine-grained face part indices (based on MediaPipe Face Mesh)
FACE_PART_INDICES = {
    "lips": [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 185, 40, 39, 37, 0, 267, 269, 270, 409, 415, 310, 311, 312, 13, 82, 81, 42, 183, 78],
    "nose": [168, 6, 197, 195, 5, 4, 1, 19, 94, 2, 98, 97, 215, 326, 327, 440],
    "left_eyebrow": [70, 63, 105, 66, 107, 55, 65, 52, 53, 46],
    "right_eyebrow": [336, 296, 334, 293, 300, 285, 295, 282, 283, 276],
    "eyebrows": [70, 63, 105, 66, 107, 55, 65, 52, 53, 46, 336, 296, 334, 293, 300, 285, 295, 282, 283, 276],
    "eyes": [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246, 263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
}


def _download_model(model_key: str, cache_dir: str | None = None) -> str:
    """Download a model file if not already cached. Returns local path."""
    if cache_dir is None:
        cache_dir = os.path.join(os.path.dirname(__file__), "models")
    os.makedirs(cache_dir, exist_ok=True)

    url = _MODEL_URLS[model_key]
    filename = url.split("/")[-1]
    # Use model_key as prefix to avoid name collisions
    local_path = os.path.join(cache_dir, f"{model_key}.tflite")

    if os.path.exists(local_path):
        return local_path

    print(f"Downloading {model_key} model...")
    import urllib.request
    urllib.request.urlretrieve(url, local_path)
    print(f"Saved to {local_path}")
    return local_path


def _ensure_mediapipe():
    """Import mediapipe with a helpful error message."""
    try:
        import mediapipe as mp
        return mp
    except ImportError:
        print(
            "ERROR: mediapipe is not installed.\n"
            "Install it with: pip install mediapipe>=0.10.9",
            file=sys.stderr,
        )
        sys.exit(1)


# ===================================================================
# Core mask generation functions
# ===================================================================

def generate_selfie_mask(
    image: np.ndarray,
    threshold: float = 0.5,
    model_path: str | None = None,
) -> np.ndarray:
    """
    Generate a binary person segmentation mask using MediaPipe Selfie Segmenter.

    Args:
        image: BGR image (as read by cv2.imread).
        threshold: Confidence threshold for the segmentation (0.0 - 1.0).
        model_path: Optional path to a custom .tflite model.

    Returns:
        Binary mask as uint8 numpy array (255 = person, 0 = background).
    """
    mp = _ensure_mediapipe()

    if model_path is None:
        model_path = _download_model("selfie_segmenter")

    BaseOptions = mp.tasks.BaseOptions
    ImageSegmenter = mp.tasks.vision.ImageSegmenter
    ImageSegmenterOptions = mp.tasks.vision.ImageSegmenterOptions
    VisionRunningMode = mp.tasks.vision.RunningMode

    options = ImageSegmenterOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=VisionRunningMode.IMAGE,
        output_category_mask=False,
        output_confidence_masks=True,
    )

    with ImageSegmenter.create_from_options(options) as segmenter:
        # MediaPipe expects RGB
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = segmenter.segment(mp_image)

        # confidence_masks[0] is the person confidence
        confidence = result.confidence_masks[0].numpy_view()
        mask = (confidence > threshold).astype(np.uint8) * 255

    return mask


def generate_selfie_multiclass_mask(
    image: np.ndarray,
    categories: list[str] | None = None,
    model_path: str | None = None,
) -> np.ndarray:
    """
    Generate a mask for specific body parts using Selfie Multiclass segmenter.

    Categories: background, hair, body_skin, face_skin, clothes, others

    Args:
        image: BGR image.
        categories: List of category names to include in the mask.
                     Defaults to ["hair", "body_skin", "face_skin", "clothes"].
        model_path: Optional path to a custom .tflite model.

    Returns:
        Binary mask as uint8 numpy array (255 = selected region, 0 = rest).
    """
    mp = _ensure_mediapipe()

    if categories is None:
        categories = ["hair", "body_skin", "face_skin", "clothes"]

    if model_path is None:
        model_path = _download_model("selfie_multiclass")

    # Resolve category names to indices
    cat_indices = set()
    for cat in categories:
        cat_lower = cat.lower()
        if cat_lower not in SELFIE_MULTICLASS_CATEGORIES:
            raise ValueError(
                f"Unknown selfie multiclass category: '{cat}'. "
                f"Available: {list(SELFIE_MULTICLASS_CATEGORIES.keys())}"
            )
        cat_indices.add(SELFIE_MULTICLASS_CATEGORIES[cat_lower])

    BaseOptions = mp.tasks.BaseOptions
    ImageSegmenter = mp.tasks.vision.ImageSegmenter
    ImageSegmenterOptions = mp.tasks.vision.ImageSegmenterOptions
    VisionRunningMode = mp.tasks.vision.RunningMode

    options = ImageSegmenterOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=VisionRunningMode.IMAGE,
        output_category_mask=True,
        output_confidence_masks=False,
    )

    with ImageSegmenter.create_from_options(options) as segmenter:
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = segmenter.segment(mp_image)

        category_mask = result.category_mask.numpy_view()
        mask = np.zeros_like(category_mask, dtype=np.uint8)
        for idx in cat_indices:
            mask[category_mask == idx] = 255

    return mask


def generate_face_mask(
    image: np.ndarray,
    model_path: str | None = None,
) -> np.ndarray:
    """
    Generate a face-only mask using Selfie Multiclass segmenter (face_skin category).

    Args:
        image: BGR image.
        model_path: Optional path to a custom .tflite model.

    Returns:
        Binary mask as uint8 numpy array (255 = face, 0 = rest).
    """
    return generate_selfie_multiclass_mask(
        image, categories=["face_skin"], model_path=model_path
    )


def generate_category_mask(
    image: np.ndarray,
    category: str = "person",
    model_path: str | None = None,
) -> np.ndarray:
    """
    Generate a mask for a specific object category using DeepLab V3.

    Categories (Pascal VOC): background, aeroplane, bicycle, bird, boat,
    bottle, bus, car, cat, chair, cow, diningtable, dog, horse, motorbike,
    person, pottedplant, sheep, sofa, train, tv.

    Args:
        image: BGR image.
        category: Category name from Pascal VOC.
        model_path: Optional path to a custom .tflite model.

    Returns:
        Binary mask as uint8 numpy array (255 = object, 0 = rest).
    """
    mp = _ensure_mediapipe()

    if model_path is None:
        model_path = _download_model("deeplab_v3")

    BaseOptions = mp.tasks.BaseOptions
    ImageSegmenter = mp.tasks.vision.ImageSegmenter
    ImageSegmenterOptions = mp.tasks.vision.ImageSegmenterOptions
    VisionRunningMode = mp.tasks.vision.RunningMode

    options = ImageSegmenterOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=VisionRunningMode.IMAGE,
        output_category_mask=True,
        output_confidence_masks=False,
    )

    with ImageSegmenter.create_from_options(options) as segmenter:
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = segmenter.segment(mp_image)

        category_mask = result.category_mask.numpy_view()
        mask = ((category_mask >= 0.5).astype(np.uint8)) * 255

    return mask


def generate_face_parts_mask(
    image: np.ndarray,
    parts: list[str] | None = None,
    model_path: str | None = None,
) -> np.ndarray:
    """
    Generate a mask for specific facial features using Face Landmarker.

    Parts: lips, nose, left_eyebrow, right_eyebrow, eyebrows, eyes

    Args:
        image: BGR image.
        parts: List of face part names to include.
               Defaults to ["lips", "nose", "eyebrows"].
        model_path: Optional path to a custom .task model.

    Returns:
        Binary mask as uint8 numpy array (255 = selected parts, 0 = rest).
    """
    mp = _ensure_mediapipe()

    if parts is None:
        parts = ["lips", "nose", "eyebrows"]

    if model_path is None:
        model_path = _download_model("face_landmarker")

    BaseOptions = mp.tasks.BaseOptions
    FaceLandmarker = mp.tasks.vision.FaceLandmarker
    FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
    VisionRunningMode = mp.tasks.vision.RunningMode

    options = FaceLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=VisionRunningMode.IMAGE,
        num_faces=1,
    )

    mask = np.zeros(image.shape[:2], dtype=np.uint8)
    h, w = image.shape[:2]

    with FaceLandmarker.create_from_options(options) as landmarker:
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = landmarker.detect(mp_image)

        if not result.face_landmarks:
            print("Warning: No face detected for parts masking.")
            return mask

        landmarks = result.face_landmarks[0]

        for part in parts:
            part_lower = part.lower()
            if part_lower not in FACE_PART_INDICES:
                print(f"Warning: Unknown face part '{part}'. Skipping.")
                continue

            indices = FACE_PART_INDICES[part_lower]
            points = []
            for idx in indices:
                lm = landmarks[idx]
                points.append([int(lm.x * w), int(lm.y * h)])

            # Draw filled polygon for the part
            points = np.array(points, dtype=np.int32)
            cv2.fillPoly(mask, [points], 255)

    return mask


# ===================================================================
# Post-processing utilities
# ===================================================================

def dilate_mask(mask: np.ndarray, pixels: int = 10) -> np.ndarray:
    """Dilate the mask to expand the inpainting region boundary."""
    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, (pixels * 2 + 1, pixels * 2 + 1)
    )
    return cv2.dilate(mask, kernel, iterations=1)


def erode_mask(mask: np.ndarray, pixels: int = 5) -> np.ndarray:
    """Erode the mask to shrink the inpainting region."""
    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, (pixels * 2 + 1, pixels * 2 + 1)
    )
    return cv2.erode(mask, kernel, iterations=1)


def smooth_mask(mask: np.ndarray, blur_size: int = 31) -> np.ndarray:
    """Apply Gaussian blur to smooth mask edges and keep the gradient."""
    if blur_size % 2 == 0:
        blur_size += 1
    blurred = cv2.GaussianBlur(mask, (blur_size, blur_size), 0)
    return blurred


def invert_mask(mask: np.ndarray) -> np.ndarray:
    """Invert the mask (swap foreground / background)."""
    return 255 - mask


def save_mask(mask: np.ndarray, output_path: str) -> None:
    """Save a single-channel mask as a 3-channel image (BrushNet format)."""
    if mask.ndim == 2:
        mask_rgb = cv2.cvtColor(mask, cv2.COLOR_GRAY2BGR)
    else:
        mask_rgb = mask
    cv2.imwrite(output_path, mask_rgb)
    print(f"Mask saved to {output_path}")


def save_masked_image(
    image: np.ndarray, mask: np.ndarray, output_path: str
) -> None:
    """Save the image with the masked region blacked out (BrushNet input format)."""
    if mask.ndim == 2:
        mask_3ch = mask[:, :, np.newaxis].repeat(3, axis=-1)
    else:
        mask_3ch = mask
    # BrushNet expects: masked region = black, unmasked = original
    masked = image * (1 - mask_3ch.astype(np.float32) / 255.0)
    cv2.imwrite(output_path, masked.astype(np.uint8))
    print(f"Masked image saved to {output_path}")


# ===================================================================
# Batch / single file processing
# ===================================================================

def process_single(
    input_path: str,
    output_path: str,
    mode: str = "selfie",
    category: str = "person",
    threshold: float = 0.5,
    dilate_px: int = 0,
    do_invert: bool = False,
    do_smooth: bool = True,
    save_preview: bool = False,
) -> np.ndarray:
    """
    Process a single image and generate + save a mask.

    Args:
        input_path: Path to the input image.
        output_path: Path to save the output mask.
        mode: One of "selfie", "face", "category", "multiclass".
        category: Category name (for "category" mode).
        threshold: Confidence threshold (for "selfie" mode).
        dilate_px: Number of pixels to dilate the mask boundary.
        do_invert: Whether to invert the mask.
        do_smooth: Whether to smooth mask edges.
        save_preview: If True, also save a masked image preview.

    Returns:
        The generated mask as numpy array.
    """
    image = cv2.imread(input_path)
    if image is None:
        raise FileNotFoundError(f"Cannot read image: {input_path}")

    # Generate mask based on mode
    if mode == "selfie":
        mask = generate_selfie_mask(image, threshold=threshold)
    elif mode == "face":
        mask = generate_face_mask(image)
    elif mode == "face_parts":
        parts = [p.strip() for p in category.split(",")]
        mask = generate_face_parts_mask(image, parts=parts)
    elif mode == "category":
        mask = generate_category_mask(image, category=category)
    elif mode == "multiclass":
        # For multiclass, category arg is comma-separated
        cats = [c.strip() for c in category.split(",")]
        mask = generate_selfie_multiclass_mask(image, categories=cats)
    else:
        raise ValueError(f"Unknown mode: {mode}. Use: selfie, face, face_parts, category, multiclass")

    # Post-processing
    if dilate_px > 0:
        mask = dilate_mask(mask, pixels=dilate_px)
    if do_smooth:
        mask = smooth_mask(mask)
    if do_invert:
        mask = invert_mask(mask)

    # Save
    save_mask(mask, output_path)

    if save_preview:
        preview_path = output_path.rsplit(".", 1)[0] + "_preview.jpg"
        save_masked_image(image, mask, preview_path)

    return mask


def process_batch(
    input_dir: str,
    output_dir: str,
    **kwargs,
) -> None:
    """Process all images in a directory."""
    os.makedirs(output_dir, exist_ok=True)

    extensions = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    image_files = sorted(
        f for f in Path(input_dir).iterdir()
        if f.suffix.lower() in extensions
    )

    if not image_files:
        print(f"No images found in {input_dir}")
        return

    print(f"Processing {len(image_files)} images...")
    for img_path in image_files:
        output_path = os.path.join(output_dir, img_path.stem + "_mask.png")
        try:
            process_single(str(img_path), output_path, **kwargs)
        except Exception as e:
            print(f"Error processing {img_path.name}: {e}")

    print("Batch processing complete.")


# ===================================================================
# CLI
# ===================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Generate segmentation masks for BrushNet inpainting using MediaPipe.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Person mask (selfie segmenter)
  python generate_mask.py -i photo.jpg -o mask.jpg -m selfie

  # Face-only mask
  python generate_mask.py -i photo.jpg -o mask.jpg -m face

  # Specific object category (DeepLab V3)
  python generate_mask.py -i photo.jpg -o mask.jpg -m category -c cat

  # Multiclass selfie (specific body parts)
  python generate_mask.py -i photo.jpg -o mask.jpg -m multiclass -c "hair,face_skin"

  # Invert mask + dilate boundary
  python generate_mask.py -i photo.jpg -o mask.jpg -m selfie --invert --dilate 15

  # Batch process
  python generate_mask.py -i ./images/ -o ./masks/ -m selfie --preview
        """,
    )

    parser.add_argument("-i", "--input", required=True, help="Input image or directory path")
    parser.add_argument("-o", "--output", required=True, help="Output mask path or directory")
    parser.add_argument(
        "-m", "--mode", default="selfie",
        choices=["selfie", "face", "face_parts", "category", "multiclass"],
        help="Segmentation mode (default: selfie)",
    )
    parser.add_argument(
        "-c", "--category", default="person",
        help="Category name for 'category' mode, or comma-separated for 'multiclass' / 'face_parts' (default: person)",
    )
    parser.add_argument(
        "-t", "--threshold", type=float, default=0.5,
        help="Confidence threshold for selfie mode (default: 0.5)",
    )
    parser.add_argument(
        "-d", "--dilate", type=int, default=0,
        help="Dilate mask boundary by N pixels (default: 0)",
    )
    parser.add_argument(
        "--invert", action="store_true",
        help="Invert the mask (mask everything except the detected region)",
    )
    parser.add_argument(
        "--no-smooth", action="store_true",
        help="Disable mask edge smoothing",
    )
    parser.add_argument(
        "--preview", action="store_true",
        help="Also save a masked image preview",
    )

    args = parser.parse_args()

    kwargs = dict(
        mode=args.mode,
        category=args.category,
        threshold=args.threshold,
        dilate_px=args.dilate,
        do_invert=args.invert,
        do_smooth=not args.no_smooth,
        save_preview=args.preview,
    )

    if os.path.isdir(args.input):
        process_batch(args.input, args.output, **kwargs)
    else:
        process_single(args.input, args.output, **kwargs)


if __name__ == "__main__":
    main()
