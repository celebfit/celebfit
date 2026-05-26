from __future__ import annotations

from api.ssl_fix import configure_ssl

configure_ssl()

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.config import get_settings
from api.routes.apply import router as apply_router
from api.routes.styles import list_styles
from api.services.pipeline import get_pipeline


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 모델은 첫 /apply 요청 시 로드 (시작 대기 시간·디스크 부족 시에도 API 즉시 기동)
    app.state.startup_error = None
    yield


app = FastAPI(
    title="celebfit API",
    description="Eyebrow style transfer backend",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(apply_router)


@app.get("/health")
def health():
    import shutil

    settings = get_settings()
    pipeline = get_pipeline(settings)
    disk = shutil.disk_usage(settings.project_root)
    disk_free_gb = round(disk.free / (1024**3), 2)

    status = {
        "status": "ok",
        "engine": "fallback" if pipeline.using_fallback else "sd_inpaint",
        "device": pipeline.device if pipeline.ready else None,
        "enable_sd": settings.enable_sd,
        "use_github_pipeline": settings.use_github_pipeline,
        "model_repo_root": str(settings.model_repo_root) if settings.model_repo_root else None,
        "disk_free_gb": disk_free_gb,
        "message": pipeline.status_message if pipeline.ready else "ready (models load on first apply)",
    }

    if settings.enable_sd and disk.free < 8 * (1024**3) and settings.model_repo_root != Path("/app/model_repo"):
        status["status"] = "warning"
        status["message"] = (
            f"디스크 여유 {disk_free_gb}GB — SD 모델(~4GB) 다운로드에 8GB+ 필요. "
            "저장 공간 확보 후 다시 시도하거나 RunPod GPU 서버 사용."
        )

    if pipeline.ready:
        status["engine"] = "fallback" if pipeline.using_fallback else (
            "github_sd_inpaint" if pipeline.github_pipeline else "sd_inpaint"
        )
        status["message"] = pipeline.status_message

    return status


@app.get("/api/v1/styles")
def get_styles():
    return {"styles": list_styles()}


if __name__ == "__main__":
    import uvicorn

    settings = get_settings()
    uvicorn.run(
        "api.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=False,
    )
