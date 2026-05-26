from __future__ import annotations

import asyncio
import base64

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from api.config import get_settings
from api.services.pipeline import get_pipeline

router = APIRouter(prefix="/api/v1", tags=["apply"])

_inference_lock = asyncio.Semaphore(1)


@router.post("/warmup")
async def warmup_models():
    settings = get_settings()
    pipeline = get_pipeline(settings)

    async with _inference_lock:
        loop = asyncio.get_event_loop()
        try:
            await loop.run_in_executor(None, pipeline.initialize)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"모델 warm-up 실패: {exc}") from exc

    return {
        "status": "ok" if pipeline.ready else "error",
        "engine": (
            "fallback"
            if pipeline.using_fallback
            else ("github_sd_inpaint" if pipeline.github_pipeline else "sd_inpaint")
        ),
        "message": pipeline.status_message,
        "device": pipeline.device,
    }


@router.post("/apply")
async def apply_style(
    image: UploadFile = File(...),
    style_id: str = Form(...),
):
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드할 수 있습니다.")

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="빈 이미지입니다.")

    settings = get_settings()
    pipeline = get_pipeline(settings)

    async with _inference_lock:
        loop = asyncio.get_event_loop()
        try:
            before_bytes, after_bytes, meta = await loop.run_in_executor(
                None,
                lambda: pipeline.apply(image_bytes, style_id),
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"스타일 적용 실패: {exc}") from exc

    return {
        "style_id": meta["style_id"],
        "style_name": meta["style_name"],
        "engine": meta["engine"],
        "device": meta["device"],
        "before_image_base64": base64.b64encode(before_bytes).decode("ascii"),
        "after_image_base64": base64.b64encode(after_bytes).decode("ascii"),
        "before_mime": "image/jpeg",
        "after_mime": "image/jpeg",
    }
