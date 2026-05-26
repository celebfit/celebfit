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


def ensure_runtime_assets(settings: Settings) -> None:
    downloads: dict[Path, str] = {
        settings.mediapipe_model: (
            "https://storage.googleapis.com/mediapipe-models/"
            "face_landmarker/face_landmarker/float16/1/face_landmarker.task"
        ),
    }

    if settings.enable_sd:
        github_raw = (
            "https://raw.githubusercontent.com/jiucai233/"
            "ConditionalImageGeneration/main/lora_checkpoint/celeb_eyebrows_all_pro_v4"
        )
        downloads.update(
            {
                settings.bisenet_weights: (
                    "https://huggingface.co/AI2lab/face-parsing.PyTorch/"
                    "resolve/main/79999_iter.pth?download=true"
                ),
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

    for destination, url in downloads.items():
        download_file(Path(destination), url)
