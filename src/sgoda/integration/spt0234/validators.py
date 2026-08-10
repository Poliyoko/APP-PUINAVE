from __future__ import annotations

import wave
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
JPEG_SIGNATURES = (b"\xff\xd8\xff",)


def validate_image_file(path: str | Path) -> dict[str, object]:
    target = Path(path)
    if not target.is_file():
        raise ValueError(f"Image file does not exist: {target}")

    data = target.read_bytes()
    if len(data) < 8:
        raise ValueError("Image file is too small.")

    if data.startswith(PNG_SIGNATURE):
        media_type = "image/png"
    elif any(data.startswith(sig) for sig in JPEG_SIGNATURES):
        media_type = "image/jpeg"
    else:
        raise ValueError("Unsupported or invalid image signature.")

    return {
        "path": str(target),
        "media_type": media_type,
        "size_bytes": len(data),
        "valid": True,
    }


def validate_wav_file(path: str | Path) -> dict[str, object]:
    target = Path(path)
    if not target.is_file():
        raise ValueError(f"Audio file does not exist: {target}")

    try:
        with wave.open(str(target), "rb") as handle:
            channels = handle.getnchannels()
            sample_width = handle.getsampwidth()
            frame_rate = handle.getframerate()
            frame_count = handle.getnframes()
            duration = frame_count / frame_rate if frame_rate else 0.0
    except (wave.Error, EOFError) as exc:
        raise ValueError(f"Invalid WAV file: {target}") from exc

    if channels < 1:
        raise ValueError("WAV must have at least one channel.")
    if sample_width < 1:
        raise ValueError("WAV sample width is invalid.")
    if frame_rate < 1:
        raise ValueError("WAV frame rate is invalid.")

    return {
        "path": str(target),
        "media_type": "audio/wav",
        "channels": channels,
        "sample_width": sample_width,
        "frame_rate": frame_rate,
        "frame_count": frame_count,
        "duration_seconds": round(duration, 6),
        "size_bytes": target.stat().st_size,
        "valid": True,
    }
