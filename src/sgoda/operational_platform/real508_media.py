from __future__ import annotations

import json
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse


PROJECT_ROOT = Path(__file__).resolve().parents[3]

CONFIG_PATH = (
    PROJECT_ROOT
    / "config"
    / "real508"
    / "media-storage.json"
)


def _config() -> dict:
    with CONFIG_PATH.open(
        "r",
        encoding="utf-8",
    ) as handle:
        return json.load(handle)


def _media_root(configured_path: str) -> Path:
    """Resolve configured Windows media paths under Windows or WSL/Linux."""
    path = Path(configured_path)

    if path.exists():
        return path.resolve()

    if (
        len(configured_path) >= 3
        and configured_path[1] == ":"
        and configured_path[2] in ("\\", "/")
    ):
        drive = configured_path[0].lower()
        remainder = configured_path[3:].replace("\\", "/")
        wsl_path = Path("/mnt") / drive / remainder

        if wsl_path.exists():
            return wsl_path.resolve()

    return path.resolve()


router = APIRouter(
    prefix="/media/real508",
    tags=["REAL508 Multimedia"],
)


@router.get("/audio/{entry_id}")
def real508_audio(entry_id: str):
    if not entry_id.isdigit() or len(entry_id) != 6:
        raise HTTPException(
            status_code=400,
            detail="Invalid REAL508 entry_id",
        )

    cfg = _config()

    root = _media_root(cfg["mp3_root"])

    candidates = sorted(
        root.glob(f"*{entry_id}*.mp3")
    )

    if len(candidates) == 0:
        raise HTTPException(
            status_code=404,
            detail="REAL508 audio not found",
        )

    if len(candidates) > 1:
        exact = [
            item
            for item in candidates
            if item.stem == entry_id
            or item.stem.startswith(entry_id + "_")
            or item.stem.endswith("_" + entry_id)
        ]

        if len(exact) == 1:
            candidates = exact
        else:
            raise HTTPException(
                status_code=409,
                detail="Ambiguous REAL508 audio mapping",
            )

    media = candidates[0]

    return FileResponse(
        path=str(media),
        media_type="audio/mpeg",
        filename=media.name,
        content_disposition_type="inline",
    )


@router.get("/image/{entry_id}")
def real508_image(entry_id: str):
    if not entry_id.isdigit() or len(entry_id) != 6:
        raise HTTPException(
            status_code=400,
            detail="Invalid REAL508 entry_id",
        )

    cfg = _config()

    root = _media_root(cfg["image_root"])

    media = root / f"{entry_id}.webp"

    if not media.is_file():
        raise HTTPException(
            status_code=404,
            detail="REAL508 image not available",
        )

    return FileResponse(
        path=str(media),
        media_type="image/webp",
        filename=media.name,
    )


@router.get("/status")
def real508_media_status():
    cfg = _config()

    audio_root = _media_root(cfg["mp3_root"])
    image_root = _media_root(cfg["image_root"])

    audio_count = len(
        list(audio_root.glob("*.mp3"))
    )

    image_count = len(
        list(image_root.glob("*.webp"))
    )

    return {
        "dataset": "REAL508",
        "audio": {
            "available": audio_count,
            "expected": 508,
        },
        "images": {
            "available": image_count,
            "current_expected": 30,
            "target": 508,
        },
        "pilot25": "FROZEN",
    }
