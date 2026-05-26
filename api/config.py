from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    api_host: str = "0.0.0.0"
    api_port: int = 8000
    project_root: Path = Path(__file__).resolve().parents[1]
    model_repo_root: Path | None = None
    weights_dir: Path = project_root / "weights"
    assets_dir: Path = project_root / "api" / "assets"
    lora_dir: Path = weights_dir / "lora" / "celeb_eyebrows_all_pro_v4"
    bisenet_weights: Path = weights_dir / "79999_iter.pth"
    mediapipe_model: Path = weights_dir / "face_landmarker.task"
    template_path: Path = assets_dir / "eyebrow_template.png"
    celebrity_data_dir: Path = project_root / "수정본"

    base_model_id: str = "emilianJR/epiCRealism"
    infer_steps: int = 40
    lora_scale: float = 1.15
    strength: float = 0.60
    guidance_scale: float = 6.0
    seed: int = 42

    allow_fallback: bool = True
    enable_sd: bool = False
    use_github_pipeline: bool = True
    # LoRA fallback download source (팀 repo 이전 시 GITHUB_REPO_SLUG 변경)
    github_repo_slug: str = "celebfit/celebfit"


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.model_repo_root is None:
        docker_default = Path("/app/model_repo")
        if docker_default.exists():
            settings.model_repo_root = docker_default
        else:
            sibling = settings.project_root.parent / "ConditionalImageGeneration"
            if sibling.exists():
                settings.model_repo_root = sibling
    settings.weights_dir.mkdir(parents=True, exist_ok=True)
    settings.assets_dir.mkdir(parents=True, exist_ok=True)
    return settings
