"""Wrapper around ConditionalImageGeneration/pipeline/main.py for byte-based inference."""

from __future__ import annotations

import io
import logging
import sys
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image, ImageOps

logger = logging.getLogger(__name__)

UNIFIED_PROMPT_TEMPLATE = (
    "a photo of {celeb} style eyebrows on a face, highly detailed, realistic skin texture, natural skin pores"
)
UNIFIED_NEGATIVE_PROMPT = (
    "low quality, distorted, blurry, messy, ugly, asymmetric eyebrows, double eyebrows,painted, drawing, illustration, cartoon, fake, 3d render, smooth skin, blurry, plastic, purple patches, colorful noise, burnt, high contrast, hard edges, dirty skin"
)


def ensure_bisenet_weights(model_repo_root: Path) -> None:
    weights_dir = model_repo_root / "masking_bisenet" / "face-parsing" / "weights"
    weights_dir.mkdir(parents=True, exist_ok=True)
    onnx_path = weights_dir / "resnet18.onnx"
    if onnx_path.exists() and onnx_path.stat().st_size > 0:
        return

    import requests

    url = "https://github.com/yakhyo/face-parsing/releases/download/weights/resnet18.onnx"
    logger.info("Downloading BiSeNet ONNX weights...")
    response = requests.get(url, stream=True, timeout=300)
    response.raise_for_status()
    with onnx_path.open("wb") as handle:
        for chunk in response.iter_content(chunk_size=1 << 20):
            if chunk:
                handle.write(chunk)


class GitHubEyebrowPipeline:
    def __init__(self, model_repo_root: Path, seed: int = 42) -> None:
        self.model_repo_root = Path(model_repo_root)
        self.seed = seed
        self._pipe = None
        self._lama = None
        self._device: str | None = None
        self._helpers = None
        self._ready = False

    @property
    def device(self) -> str:
        return self._device or "cpu"

    @property
    def ready(self) -> bool:
        return self._ready

    def initialize(self) -> None:
        if self._ready:
            return

        repo_root = str(self.model_repo_root.resolve())
        if repo_root not in sys.path:
            sys.path.insert(0, repo_root)

        ensure_bisenet_weights(self.model_repo_root)

        from masking_bisenet.generate_mask_bisenet import generate_bisenet_face_parts_mask
        from pipeline.main import (
            color_transfer,
            get_canny_guide,
            load_models,
            make_brow_mask_from_landmarks,
        )
        from util.crop_face import apply_crop, get_zoom_crop_info, restore_crop
        from util.dilate_mask import dilate_mask
        from util.smooth_mask import smooth_mask

        self._helpers = {
            "generate_bisenet_face_parts_mask": generate_bisenet_face_parts_mask,
            "dilate_mask": dilate_mask,
            "smooth_mask": smooth_mask,
            "get_zoom_crop_info": get_zoom_crop_info,
            "apply_crop": apply_crop,
            "restore_crop": restore_crop,
            "make_brow_mask_from_landmarks": make_brow_mask_from_landmarks,
            "get_canny_guide": get_canny_guide,
            "color_transfer": color_transfer,
        }

        logger.info("Loading GitHub SD Inpaint + LoRA pipeline from %s", repo_root)
        self._pipe, self._lama, self._device = load_models()
        self._ready = True
        logger.info("GitHub pipeline ready on %s", self._device)

    def apply(self, image_bytes: bytes, celeb_name: str) -> tuple[bytes, bytes]:
        self.initialize()
        assert self._pipe is not None and self._lama is not None and self._helpers is not None

        image = ImageOps.exif_transpose(Image.open(io.BytesIO(image_bytes)).convert("RGB"))
        original_bgr = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        h, w = original_bgr.shape[:2]

        helpers = self._helpers
        raw_mask_base = helpers["generate_bisenet_face_parts_mask"](original_bgr, parts=["eyebrows"])
        raw_mask_base = helpers["dilate_mask"](raw_mask_base, pixels=0)
        raw_mask_base = helpers["smooth_mask"](raw_mask_base)

        crop_info = helpers["get_zoom_crop_info"](
            raw_mask_base, original_bgr.shape, padding_ratio=1.3, min_size=512
        )
        image_512 = helpers["apply_crop"](original_bgr, crop_info, target_size=512)
        mask_512_binary = helpers["apply_crop"](raw_mask_base, crop_info, target_size=512)

        mask_512_adaptive = helpers["make_brow_mask_from_landmarks"](image_512, padding_ratio=0.5)
        if np.sum(mask_512_adaptive) == 0:
            mask_512_adaptive = mask_512_binary

        image_pil = Image.fromarray(cv2.cvtColor(image_512, cv2.COLOR_BGR2RGB))
        mask_pil = Image.fromarray(mask_512_adaptive).convert("L")

        no_brow_pil = image_pil
        for _ in range(3):
            no_brow_pil = self._lama(no_brow_pil, mask_pil)
        masked_image_512 = cv2.cvtColor(np.array(no_brow_pil), cv2.COLOR_RGB2BGR)

        image_pil = Image.fromarray(cv2.cvtColor(masked_image_512, cv2.COLOR_BGR2RGB))
        pipe_mask_pil = Image.new("RGB", (512, 512), "white")
        control_image_pil = helpers["get_canny_guide"](image_512)

        prompt = UNIFIED_PROMPT_TEMPLATE.format(celeb=celeb_name)
        generator = torch.Generator(self._device).manual_seed(self.seed)
        output_pil = self._pipe(
            prompt=prompt,
            negative_prompt=UNIFIED_NEGATIVE_PROMPT,
            image=image_pil,
            mask_image=pipe_mask_pil,
            control_image=control_image_pil,
            controlnet_conditioning_scale=0,
            num_inference_steps=40,
            guidance_scale=6.0,
            strength=0.60,
            generator=generator,
        ).images[0]

        result_bgr_512 = cv2.cvtColor(np.array(output_pil), cv2.COLOR_RGB2BGR)
        corrected_bgr_512 = helpers["color_transfer"](result_bgr_512, masked_image_512, mask_512_binary)
        restored_full = helpers["restore_crop"](corrected_bgr_512, crop_info, original_bgr.shape)
        restored_erased_full = helpers["restore_crop"](masked_image_512, crop_info, original_bgr.shape)

        orig_mask_np = raw_mask_base.astype(np.float32) / 255.0
        if len(orig_mask_np.shape) == 2:
            orig_mask_np = orig_mask_np[:, :, np.newaxis]

        ksize = int(max(original_bgr.shape[:2]) * 0.008) | 1
        orig_mask_blurred = cv2.GaussianBlur(orig_mask_np, (ksize, ksize), 0)
        if len(orig_mask_blurred.shape) == 2:
            orig_mask_blurred = orig_mask_blurred[:, :, np.newaxis]
        original_erased_bgr = (
            restored_erased_full * orig_mask_blurred + original_bgr * (1.0 - orig_mask_blurred)
        ).astype(np.uint8)

#        new_raw_mask = helpers["generate_bisenet_face_parts_mask"](corrected_bgr_512, parts=["eyebrows"])
#        if np.sum(new_raw_mask) == 0:
#          new_processed_mask = mask_512_binary
#        else:
#          new_processed_mask = helpers["smooth_mask"](helpers["dilate_mask"](new_raw_mask, pixels=1))

        # 512x512에서 마스크 먼저 적용 → 눈썹 픽셀만 남김
#        mask_float_512 = new_processed_mask.astype(np.float32) / 255.0
#        eyebrow_only_512 = (corrected_bgr_512 * mask_float_512[:, :, np.newaxis]).astype(np.uint8)

        # 원본 크기로 복원
#        restored_eyebrow = helpers["restore_crop"](eyebrow_only_512, crop_info, original_bgr.shape)
#        restored_mask = helpers["restore_crop"](new_processed_mask, crop_info, original_bgr.shape[:2])

#        restored_mask_np = restored_mask.astype(np.float32) / 255.0
#        if len(restored_mask_np.shape) == 2:
#          restored_mask_np = restored_mask_np[:, :, np.newaxis]
#        restored_mask_blurred = cv2.GaussianBlur(restored_mask_np, (ksize, ksize), 0)
        
#        if len(restored_mask_blurred.shape) == 2:
#          restored_mask_blurred = restored_mask_blurred[:, :, np.newaxis]

#        final_result_bgr = (
#          restored_eyebrow * restored_mask_blurred + original_erased_bgr * (1.0 - restored_mask_blurred)
#        ).astype(np.uint8)
        

        new_raw_mask = helpers["generate_bisenet_face_parts_mask"](corrected_bgr_512, parts=["eyebrows"])
        if np.sum(new_raw_mask) == 0:
            new_processed_mask = mask_512_binary
        else:
            new_processed_mask = helpers["smooth_mask"](helpers["dilate_mask"](new_raw_mask, pixels=1))

        new_restored_mask = helpers["restore_crop"](new_processed_mask, crop_info, original_bgr.shape[:2])
        new_mask_np = new_restored_mask.astype(np.float32) / 255.0
        if len(new_mask_np.shape) == 2:
            new_mask_np = new_mask_np[:, :, np.newaxis]
        new_mask_blurred = cv2.GaussianBlur(new_mask_np, (ksize, ksize), 0)
        if len(new_mask_blurred.shape) == 2:
            new_mask_blurred = new_mask_blurred[:, :, np.newaxis]

        final_result_bgr = (
            restored_full * new_mask_blurred + original_erased_bgr * (1.0 - new_mask_blurred)
        ).astype(np.uint8)

        
        before_bytes = self._encode_jpeg(original_bgr)
        after_bytes = self._encode_jpeg(final_result_bgr)
        return before_bytes, after_bytes

    @staticmethod
    def _encode_jpeg(image_bgr: np.ndarray, quality: int = 92) -> bytes:
        ok, encoded = cv2.imencode(".jpg", image_bgr, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
        if not ok:
            raise RuntimeError("Failed to encode result image.")
        return encoded.tobytes()
