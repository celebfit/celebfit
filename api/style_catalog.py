"""Style catalog shared by API and app."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class StyleDefinition:
    id: str
    name: str
    label: str
    tags: list[str]
    celeb_prompt: str | None
    generic_prompt: str | None = None


STYLES: list[StyleDefinition] = [
    StyleDefinition(
        id="go_yoonjung",
        name="고윤정",
        label="자연",
        tags=["자연", "밝은인상"],
        celeb_prompt="고윤정",
    ),
    StyleDefinition(
        id="shin_sekyung",
        name="신세경",
        label="세미아치",
        tags=["세미아치", "선명한인상"],
        celeb_prompt="신세경",
    ),
    StyleDefinition(
        id="hong_sooju",
        name="홍수주",
        label="일자",
        tags=["일자", "자연"],
        celeb_prompt="홍수주",
    ),
    StyleDefinition(
        id="choi_siwon",
        name="최시원",
        label="차분·또렷",
        tags=["차분", "또렷한인상"],
        celeb_prompt="최시원",
    ),
    StyleDefinition(
        id="v",
        name="뷔",
        label="소프트 아치",
        tags=["소프트 아치", "자연"],
        celeb_prompt="뷔",
    ),
    StyleDefinition(
        id="cha_eunwoo",
        name="차은우",
        label="깔끔 일자",
        tags=["일자", "선명한인상"],
        celeb_prompt="차은우",
    ),
    StyleDefinition(
        id="natural",
        name="내추럴",
        label="자연",
        tags=["자연"],
        celeb_prompt=None,
        generic_prompt="natural soft eyebrows, realistic hair texture",
    ),
    StyleDefinition(
        id="soft_arch",
        name="소프트 아치",
        label="소프트 아치",
        tags=["소프트 아치", "밝은인상"],
        celeb_prompt=None,
        generic_prompt="soft arched eyebrows, gentle curve, natural look",
    ),
    StyleDefinition(
        id="straight",
        name="일자",
        label="일자",
        tags=["일자", "선명한인상"],
        celeb_prompt=None,
        generic_prompt="straight eyebrows, clean defined shape",
    ),
]

STYLE_BY_ID = {style.id: style for style in STYLES}

NEGATIVE_PROMPT = (
    "low quality, distorted, blurry, messy, ugly, "
    "asymmetric eyebrows, double eyebrows, cartoon, painting"
)
