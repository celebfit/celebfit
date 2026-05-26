from __future__ import annotations

from pathlib import Path

import requests

from api.config import Settings


def download_file(path: Path, url: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.stat().st_size > 0:
        return
    response = requests.get(url, stream=True, timeout=300)
    response.raise_for_status()
    with path.open("wb") as handle:
        for chunk in response.iter_content(chunk_size=1 << 20):
            if chunk:
                handle.write(chunk)


def _lora_files_present(lora_dir: Path) -> bool:
    required = [
        lora_dir / "unet" / "adapter_config.json",
        lora_dir / "unet" / "adapter_model.safetensors",
        lora_dir / "text_encoder" / "adapter_config.json",
        lora_dir / "text_encoder" / "adapter_model.safetensors",
    ]
    return all(path.exists() and path.stat().st_size > 0 for path in required)


def _resolve_lora_dir(settings: Settings) -> Path:
    if _lora_files_present(settings.lora_dir):
        return settings.lora_dir
    if settings.model_repo_root:
        repo_lora = settings.model_repo_root / "lora_checkpoint" / "celeb_eyebrows_all_pro_v4"
        if _lora_files_present(repo_lora):
            return repo_lora
    return settings.lora_dir


def ensure_runtime_assets(settings: Settings) -> None:
    downloads: dict[Path, str] = {
        settings.mediapipe_model: (
            "https://storage.googleapis.com/mediapipe-models/"
            "face_landmarker/face_landmarker/float16/1/face_landmarker.task"
        ),
    }

    if settings.enable_sd:
        lora_dir = _resolve_lora_dir(settings)
        if not _lora_files_present(lora_dir):
            github_raw = (
                f"https://raw.githubusercontent.com/{settings.github_repo_slug}/main/"
                "lora_checkpoint/celeb_eyebrows_all_pro_v4"
            )
            downloads.update(
                {
                    settings.lora_dir / "unet" / "adapter_config.json": (
                        f"{github_raw}/unet/adapter_config.json"
                    ),
                    settings.lora_dir / "unet" / "adapter_model.safetensors": (
                        f"{github_raw}/unet/adapter_model.safetensors"
                    ),
                    settings.lora_dir / "text_encoder" / "adapter_config.json": (
                        f"{github_raw}/text_encoder/adapter_config.json"
                    ),
                    settings.lora_dir / "text_encoder" / "adapter_model.safetensors": (
                        f"{github_raw}/text_encoder/adapter_model.safetensors"
                    ),
                }
            )

        if not settings.bisenet_weights.exists() or settings.bisenet_weights.stat().st_size == 0:
            downloads[settings.bisenet_weights] = (
                "https://huggingface.co/AI2lab/face-parsing.PyTorch/"
                "resolve/main/79999_iter.pth?download=true"
            )

    for destination, url in downloads.items():
        download_file(Path(destination), url)
