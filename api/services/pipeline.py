from __future__ import annotations

import logging

import cv2
import numpy as np
from PIL import Image

from api.config import Settings
from api.services.assets import ensure_runtime_assets, resolve_lora_dir
from api.services.inpaint_service import FallbackStyleService, image_to_bytes
from api.services.mask_service import FaceMaskService
from api.style_catalog import STYLE_BY_ID, StyleDefinition

logger = logging.getLogger(__name__)


def detect_device() -> str:
    try:
        import torch

        if torch.cuda.is_available():
            return "cuda"
        if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
            return "mps"
        return "cpu"
    except ImportError:
        return "cpu"


class EyebrowPipeline:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.device = detect_device()
        self.mask_service: FaceMaskService | None = None
        self.lama_service = None
        self.inpaint_service = None
        self.github_pipeline = None
        self._ready = False
        self._using_fallback = not settings.enable_sd
        self._status_message = "not initialized"

    @property
    def ready(self) -> bool:
        return self._ready

    @property
    def using_fallback(self) -> bool:
        return self._using_fallback

    @property
    def status_message(self) -> str:
        return self._status_message

    def initialize(self) -> None:
        if self._ready:
            return

        logger.info("Initializing eyebrow pipeline...")
        ensure_runtime_assets(self.settings)
        self._load_template()
        self.mask_service = FaceMaskService(str(self.settings.mediapipe_model))

        if self.settings.template_path.exists():
            template = np.array(Image.open(self.settings.template_path).convert("L"))
            self.mask_service.set_template(template)

        if self.settings.enable_sd:
            self._try_load_sd_pipeline()
        else:
            self._using_fallback = True
            self._status_message = (
                "mediapipe + fallback (ENABLE_SD=true 로 SD 모델 활성화)"
            )

        self._ready = True
        logger.info("Pipeline status: %s", self._status_message)

    def _try_load_sd_pipeline(self) -> None:
        if (
            self.settings.use_github_pipeline
            and self.settings.model_repo_root
            and self.settings.model_repo_root.exists()
        ):
            try:
                from api.services.github_pipeline import GitHubEyebrowPipeline

                self.github_pipeline = GitHubEyebrowPipeline(
                    self.settings.model_repo_root,
                    seed=self.settings.seed,
                )
                self.github_pipeline.initialize()
                self.device = self.github_pipeline.device
                self._using_fallback = False
                self._status_message = (
                    f"github sd_inpaint ready ({self.device}, "
                    f"{self.settings.model_repo_root.name})"
                )
                return
            except Exception as exc:
                logger.warning("GitHub pipeline unavailable, trying local SD: %s", exc)

        try:
            from api.services.inpaint_service import InpaintService, LamaService

            self.lama_service = LamaService()
            lora_dir = resolve_lora_dir(self.settings)
            self.inpaint_service = InpaintService(
                base_model_id=self.settings.base_model_id,
                lora_dir=lora_dir,
                device=self.device,
                infer_steps=self.settings.infer_steps,
                lora_scale=self.settings.lora_scale,
                strength=self.settings.strength,
                guidance_scale=self.settings.guidance_scale,
                seed=self.settings.seed,
            )
            self.lama_service._ensure_loaded()
            self.inpaint_service._ensure_loaded()
            self._using_fallback = False
            self._status_message = f"sd_inpaint ready ({self.device})"
        except Exception as exc:
            logger.warning("Diffusion pipeline unavailable, using fallback: %s", exc)
            if not self.settings.allow_fallback:
                raise RuntimeError(
                    f"SD 모델 로드 실패: {exc}. "
                    "디스크 여유 8GB+ 확인 후 ./scripts/start_api_gpu.sh 재실행."
                ) from exc
            self.lama_service = None
            self.inpaint_service = None
            self.github_pipeline = None
            self._using_fallback = True
            self._status_message = f"mediapipe + fallback ({exc.__class__.__name__})"

    def _load_template(self) -> None:
        if self.settings.template_path.exists():
            return

        template = self._build_template_from_landmarks()
        if template is not None:
            Image.fromarray(template).save(self.settings.template_path)
            logger.info("Generated default eyebrow template at %s", self.settings.template_path)

    def _build_template_from_landmarks(self) -> np.ndarray | None:
        canvas = 512
        template = np.zeros((canvas, canvas), dtype=np.uint8)
        y_center = int(canvas * 0.33)
        for x_center, direction in ((int(canvas * 0.35), -1), (int(canvas * 0.65), 1)):
            points = []
            for t in range(21):
                x = x_center + direction * (t - 10) * 7
                y = y_center + int(8 * np.sin(t / 20 * np.pi))
                points.append([x, y])
            cv2.polylines(template, [np.array(points, dtype=np.int32)], False, 255, 8)
        template = cv2.dilate(template, np.ones((9, 9), np.uint8), iterations=2)
        return template

    def apply(self, image_bytes: bytes, style_id: str) -> tuple[bytes, bytes, dict]:
        self.initialize()
        assert self.mask_service is not None

        style = STYLE_BY_ID.get(style_id)
        if style is None:
            raise ValueError(f"Unknown style_id: {style_id}")

        if (
            style.celeb_prompt
            and self.github_pipeline is not None
            and not self._using_fallback
        ):
            before_bytes, after_bytes = self.github_pipeline.apply(
                image_bytes,
                style.celeb_prompt,
            )
            engine = "github_sd_inpaint"
        else:
            original_image, masks = self.mask_service.build_masks(image_bytes)
            before_for_model = original_image.resize((512, 512))

            if self._using_fallback or self.lama_service is None or self.inpaint_service is None:
                after_image = FallbackStyleService.apply(
                    before_for_model, masks.inpaint_mask, style
                )
            else:
                no_brow_image = self.lama_service.remove_eyebrows(
                    before_for_model, masks.erase_mask
                )
                after_image = self.inpaint_service.generate(
                    no_brow_image, masks.inpaint_mask, style
                )

            before_bytes = image_to_bytes(original_image)
            after_bytes = image_to_bytes(after_image)
            engine = "fallback" if self._using_fallback else "sd_inpaint"

        meta = {
            "style_id": style.id,
            "style_name": style.name,
            "engine": engine,
            "device": self.device,
        }
        return before_bytes, after_bytes, meta


_pipeline: EyebrowPipeline | None = None


def get_pipeline(settings: Settings) -> EyebrowPipeline:
    global _pipeline
    if _pipeline is None:
        _pipeline = EyebrowPipeline(settings)
    return _pipeline
