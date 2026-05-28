from __future__ import annotations
import io
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

from api.style_catalog import NEGATIVE_PROMPT, StyleDefinition


class LamaService:
    def __init__(self) -> None:
        self._lama = None

    def _ensure_loaded(self) -> None:
        if self._lama is None:
            from simple_lama_inpainting import SimpleLama

            self._lama = SimpleLama()

    def remove_eyebrows(self, image: Image.Image, erase_mask: np.ndarray) -> Image.Image:
        self._ensure_loaded()
        mask_pil = Image.fromarray(erase_mask).convert("L")
        result = image
        for _ in range(3):
            result = self._lama(result, mask_pil)
        return result


class InpaintService:
    def __init__(
        self,
        base_model_id: str,
        lora_dir: Path,
        device: str,
        infer_steps: int,
        lora_scale: float,
        strength: float,
        guidance_scale: float,
        seed: int,
    ) -> None:
        self.base_model_id = base_model_id
        self.lora_dir = lora_dir
        self.device = device
        self.infer_steps = infer_steps
        self.lora_scale = lora_scale
        self.strength = strength
        self.guidance_scale = guidance_scale
        self.seed = seed
        self._pipe = None

    def _ensure_loaded(self) -> None:
        if self._pipe is not None:
            return

        import torch
        from diffusers import StableDiffusionInpaintPipeline
        from peft import PeftModel

        dtype = torch.float16 if self.device in ("cuda", "mps") else torch.float32
        pipe = StableDiffusionInpaintPipeline.from_pretrained(
            self.base_model_id,
            torch_dtype=dtype,
            safety_checker=None,
        ).to(self.device)

        pipe.unet = PeftModel.from_pretrained(
            pipe.unet,
            str(self.lora_dir / "unet"),
            adapter_name="celebs",
        ).to(dtype=dtype)
        pipe.text_encoder = PeftModel.from_pretrained(
            pipe.text_encoder,
            str(self.lora_dir / "text_encoder"),
            adapter_name="celebs",
        ).to(dtype=dtype)
        pipe.set_progress_bar_config(disable=True)
        self._pipe = pipe

    @staticmethod
    def _build_prompt(style: StyleDefinition) -> str:
        if style.celeb_prompt:
            return (
                f"a photo of {style.celeb_prompt} style eyebrows, "
                "highly detailed, natural hair texture, masterpiece, 8k uhd"
            )
        return f"a photo of {style.generic_prompt}, highly detailed, natural hair texture, 8k uhd"

    @staticmethod
    def blend(original: Image.Image, generated: Image.Image, mask: Image.Image, sigma: float = 3.0) -> Image.Image:
        orig = np.array(original).astype(float)
        gen = np.array(generated).astype(float)
        mask_arr = np.array(mask).astype(float) / 255.0
        soft = gaussian_filter(mask_arr, sigma=sigma)[:, :, np.newaxis]
        merged = (orig * (1 - soft) + gen * soft).astype(np.uint8)
        return Image.fromarray(merged)

    def generate(
        self,
        base_image: Image.Image,
        inpaint_mask: np.ndarray,
        style: StyleDefinition,
    ) -> Image.Image:
        import torch

        self._ensure_loaded()
        assert self._pipe is not None

        original_size = base_image.size
        init_512 = base_image.resize((512, 512))
        mask_512 = Image.fromarray(cv2.resize(inpaint_mask, (512, 512), interpolation=cv2.INTER_NEAREST)).convert("L")

        scale = self.lora_scale if style.celeb_prompt else max(0.35, self.lora_scale * 0.5)
        generator = torch.Generator(device=self.device).manual_seed(self.seed)
        generated = self._pipe(
            prompt=self._build_prompt(style),
            negative_prompt=NEGATIVE_PROMPT,
            image=init_512,
            mask_image=mask_512,
            strength=self.strength,
            num_inference_steps=self.infer_steps,
            guidance_scale=self.guidance_scale,
            cross_attention_kwargs={"scale": scale},
            generator=generator,
        ).images[0]

        blended = self.blend(init_512, generated, mask_512)
        return blended.resize(original_size, Image.LANCZOS)


class FallbackStyleService:
    """Runs when diffusion weights are unavailable (CPU-only dev preview)."""

    @staticmethod
    def apply(image: Image.Image, inpaint_mask: np.ndarray, style: StyleDefinition) -> Image.Image:
        rgb = np.array(image).copy()
        mask = cv2.resize(inpaint_mask, (rgb.shape[1], rgb.shape[0]))
        ys, xs = np.where(mask > 0)
        if len(xs) == 0:
            return image

        tint_map = {
            "go_yoonjung": (92, 68, 58),
            "shin_sekyung": (78, 58, 48),
            "hong_sooju": (88, 72, 62),
            "choi_siwon": (72, 62, 54),
            "v": (68, 58, 50),
            "cha_eunwoo": (80, 70, 62),
            "natural": (96, 76, 66),
            "soft_arch": (84, 64, 54),
            "straight": (90, 70, 60),
        }
        tint = np.array(tint_map.get(style.id, (90, 70, 60)), dtype=np.float32)

        overlay = rgb.astype(np.float32)
        strength = 0.28
        overlay[mask > 0] = overlay[mask > 0] * (1 - strength) + tint * strength
        blurred = cv2.GaussianBlur(overlay.astype(np.uint8), (5, 5), 0)

        alpha = (mask.astype(np.float32) / 255.0)[:, :, np.newaxis]
        alpha = gaussian_filter(alpha, sigma=2.5)
        merged = rgb.astype(np.float32) * (1 - alpha) + blurred.astype(np.float32) * alpha
        return Image.fromarray(np.clip(merged, 0, 255).astype(np.uint8))


def image_to_bytes(image: Image.Image, fmt: str = "JPEG", quality: int = 92) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format=fmt, quality=quality)
    return buffer.getvalue()
