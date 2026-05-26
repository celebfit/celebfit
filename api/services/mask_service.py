from __future__ import annotations

import io
from dataclasses import dataclass

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from PIL import Image, ImageOps

CANVAS = 512
DST_L_EYE = np.float32([CANVAS * 0.35, CANVAS * 0.36])
DST_R_EYE = np.float32([CANVAS * 0.65, CANVAS * 0.36])
L_EYE_IDX = [33, 133, 159, 145, 160, 144]
R_EYE_IDX = [263, 362, 386, 374, 387, 373]

LEFT_BROW = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46]
RIGHT_BROW = [300, 293, 334, 296, 336, 285, 295, 282, 283, 276]
LEFT_EYE = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
RIGHT_EYE = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]


@dataclass
class FaceMaskBundle:
    inpaint_mask: np.ndarray
    erase_mask: np.ndarray
    width: int
    height: int


class FaceMaskService:
    def __init__(self, mediapipe_model_path: str) -> None:
        options = vision.FaceLandmarkerOptions(
            base_options=python.BaseOptions(
                model_asset_path=mediapipe_model_path,
                delegate=python.BaseOptions.Delegate.CPU,
            ),
            num_faces=1,
        )
        self._detector = vision.FaceLandmarker.create_from_options(options)
        self._template: np.ndarray | None = None

    def set_template(self, template: np.ndarray) -> None:
        self._template = template

    def _load_image(self, image_bytes: bytes) -> tuple[Image.Image, np.ndarray]:
        image = ImageOps.exif_transpose(Image.open(io.BytesIO(image_bytes)).convert("RGB"))
        return image, np.asarray(image)

    def _detect_landmarks(self, image_rgb: np.ndarray):
        if image_rgb.dtype != np.uint8:
            image_rgb = np.clip(image_rgb, 0, 255).astype(np.uint8)
        rgb = np.ascontiguousarray(image_rgb)
        result = self._detector.detect(
            mp.Image(
                image_format=mp.ImageFormat.SRGB,
                data=rgb,
            )
        )
        if not result.face_landmarks:
            raise ValueError("얼굴을 찾지 못했습니다. 정면 셀카를 업로드해주세요.")
        return result.face_landmarks[0]

    @staticmethod
    def _eye_centers(landmarks, width: int, height: int) -> tuple[np.ndarray, np.ndarray]:
        left = np.mean([[landmarks[i].x * width, landmarks[i].y * height] for i in L_EYE_IDX], axis=0)
        right = np.mean([[landmarks[i].x * width, landmarks[i].y * height] for i in R_EYE_IDX], axis=0)
        return left.astype(np.float32), right.astype(np.float32)

    @staticmethod
    def _dilate(mask: np.ndarray, kernel_size: int) -> np.ndarray:
        if kernel_size <= 0:
            return mask
        kernel = cv2.getStructuringElement(
            cv2.MORPH_ELLIPSE,
            (kernel_size * 2 + 1, kernel_size * 2 + 1),
        )
        return cv2.dilate(mask, kernel, iterations=1)

    def _method2_mask(self, landmarks, width: int, height: int) -> np.ndarray:
        if self._template is None:
            raise ValueError("눈썹 템플릿이 준비되지 않았습니다.")

        left_eye, right_eye = self._eye_centers(landmarks, width, height)
        matrix, _ = cv2.estimateAffinePartial2D(
            np.stack([left_eye, right_eye]),
            np.stack([DST_L_EYE, DST_R_EYE]),
            method=cv2.LMEDS,
        )
        if matrix is None:
            raise ValueError("얼굴 정렬에 실패했습니다.")

        inverse = cv2.invertAffineTransform(matrix)
        mask = cv2.warpAffine(self._template, inverse, (width, height))
        mask = self._dilate(mask, 4)
        horizontal_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (21, 1))
        mask = cv2.dilate(mask, horizontal_kernel)
        return mask

    def _landmark_brow_mask(
        self,
        landmarks,
        width: int,
        height: int,
        padding_ratio: float = 0.5,
    ) -> np.ndarray:
        brow_mask = np.zeros((height, width), dtype=np.uint8)
        eye_mask = np.zeros((height, width), dtype=np.uint8)

        for brow_indices in (LEFT_BROW, RIGHT_BROW):
            points = np.array(
                [[int(landmarks[i].x * width), int(landmarks[i].y * height)] for i in brow_indices]
            )
            x_min, y_min = points.min(axis=0)
            x_max, y_max = points.max(axis=0)
            brow_w = x_max - x_min
            brow_h = y_max - y_min
            pad_x = int(brow_w * padding_ratio)
            pad_y = int(brow_h * padding_ratio * 2)

            x_min = max(0, x_min - pad_x)
            x_max = min(width, x_max + pad_x)
            y_min = max(0, y_min - pad_y)
            y_max = min(height, y_max + pad_y)

            hull = cv2.convexHull(points)
            cv2.fillConvexPoly(brow_mask, hull, 255)
            brow_mask[y_min:y_max, x_min:x_max] = cv2.bitwise_or(
                brow_mask[y_min:y_max, x_min:x_max],
                np.full((y_max - y_min, x_max - x_min), 255, dtype=np.uint8),
            )

        for eye_indices in (LEFT_EYE, RIGHT_EYE):
            points = np.array(
                [[int(landmarks[i].x * width), int(landmarks[i].y * height)] for i in eye_indices]
            )
            hull = cv2.convexHull(points)
            cv2.fillConvexPoly(eye_mask, hull, 255)
        eye_mask = self._dilate(eye_mask, 6)

        final_mask = cv2.bitwise_and(brow_mask, cv2.bitwise_not(eye_mask))
        final_mask = cv2.GaussianBlur(final_mask, (11, 11), 0)
        _, final_mask = cv2.threshold(final_mask, 127, 255, cv2.THRESH_BINARY)
        return final_mask

    def build_masks(self, image_bytes: bytes) -> tuple[Image.Image, FaceMaskBundle]:
        image, rgb = self._load_image(image_bytes)
        height, width = rgb.shape[:2]
        landmarks = self._detect_landmarks(rgb)

        erase_mask = self._landmark_brow_mask(landmarks, width, height)
        try:
            inpaint_mask = self._method2_mask(landmarks, width, height)
        except ValueError:
            inpaint_mask = erase_mask.copy()

        return image, FaceMaskBundle(
            inpaint_mask=inpaint_mask,
            erase_mask=erase_mask,
            width=width,
            height=height,
        )
