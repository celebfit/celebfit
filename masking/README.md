# MediaPipe Mask Generation for BrushNet

Generate segmentation masks automatically using MediaPipe, ready to use as BrushNet inpainting inputs.

## Setup

```bash
pip install -r requirements.txt
```

Models are downloaded automatically on first use to `mediapipe/models/`.

## Segmentation Modes

| Mode | Model | Description |
|------|-------|-------------|
| `selfie` | Selfie Segmenter | Person vs background (binary) |
| `face` | Selfie Multiclass | Face skin region only |
| `multiclass` | Selfie Multiclass | Select body parts: `hair`, `body_skin`, `face_skin`, `clothes` |
| `category` | DeepLab V3 | 21 Pascal VOC categories (person, car, cat, dog, etc.) |

## CLI Usage

```bash
# Person mask
python generate_mask.py -i photo.jpg -o mask.jpg -m selfie

# Face mask
python generate_mask.py -i photo.jpg -o mask.jpg -m face

# Cat mask (DeepLab V3)
python generate_mask.py -i photo.jpg -o mask.jpg -m category -c cat

# Hair + face mask
python generate_mask.py -i photo.jpg -o mask.jpg -m multiclass -c "hair,face_skin"

# Invert + dilate
python generate_mask.py -i photo.jpg -o mask.jpg -m selfie --invert --dilate 15

# Batch process a directory
python generate_mask.py -i ./images/ -o ./masks/ -m selfie --preview
```

## Python API

```python
import cv2
from generate_mask import generate_selfie_mask, generate_face_mask, dilate_mask, save_mask

image = cv2.imread("photo.jpg")

# Generate person mask
mask = generate_selfie_mask(image, threshold=0.5)

# Generate face-only mask
mask = generate_face_mask(image)

# Post-process
mask = dilate_mask(mask, pixels=10)

# Save
save_mask(mask, "mask.jpg")
```

## DeepLab V3 Categories

`background`, `aeroplane`, `bicycle`, `bird`, `boat`, `bottle`, `bus`, `car`, `cat`, `chair`, `cow`, `diningtable`, `dog`, `horse`, `motorbike`, `person`, `pottedplant`, `sheep`, `sofa`, `train`, `tv`
