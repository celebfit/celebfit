from __future__ import annotations

from api.style_catalog import STYLES


def list_styles() -> list[dict]:
    return [
        {
            "id": style.id,
            "name": style.name,
            "label": style.label,
            "tags": style.tags,
        }
        for style in STYLES
    ]
