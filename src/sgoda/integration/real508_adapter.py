"""Adaptador institucional REAL-508 para SGODA-PUINAVE.

Integra la línea base léxica/audio certificada sin copiar multimedia
masiva al repositorio Git y sin modificar la grafía Puinave.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from sgoda.lexical_engine.models import MultimediaResource


REAL508_FIRST_ID = 1
REAL508_LAST_ID = 508
REAL508_COUNT = 508


@dataclass(frozen=True, slots=True)
class Real508StorageConfig:
    """Configuración parametrizable del almacenamiento multimedia REAL-508."""

    wav_root: Path
    mp3_root: Path
    public_mp3_base_url: str | None = None

    @classmethod
    def from_dict(cls, payload: dict[str, object]) -> "Real508StorageConfig":
        wav_root = str(payload.get("wav_root") or "").strip()
        mp3_root = str(payload.get("mp3_root") or "").strip()
        public_url = str(payload.get("public_mp3_base_url") or "").strip()

        if not wav_root:
            raise ValueError("REAL508 requiere wav_root.")

        if not mp3_root:
            raise ValueError("REAL508 requiere mp3_root.")

        return cls(
            wav_root=Path(wav_root),
            mp3_root=Path(mp3_root),
            public_mp3_base_url=public_url or None,
        )


def canonical_real508_id(value: int | str) -> str:
    """Devuelve el ID REAL-508 en formato institucional de seis dígitos."""

    try:
        number = int(str(value).strip())
    except (TypeError, ValueError) as exc:
        raise ValueError(f"ID REAL508 inválido: {value!r}") from exc

    if number < REAL508_FIRST_ID or number > REAL508_LAST_ID:
        raise ValueError(
            f"ID REAL508 fuera de rango: {number}. "
            f"Rango permitido: {REAL508_FIRST_ID:06d}-{REAL508_LAST_ID:06d}."
        )

    return f"{number:06d}"


def wav_path(
    entry_id: int | str,
    config: Real508StorageConfig,
) -> Path:
    """Resuelve el WAV maestro/distribución sin modificarlo."""

    canonical_id = canonical_real508_id(entry_id)
    return config.wav_root / f"{canonical_id}.wav"


def mp3_path(
    entry_id: int | str,
    config: Real508StorageConfig,
) -> Path:
    """Resuelve el MP3 de distribución."""

    canonical_id = canonical_real508_id(entry_id)
    return config.mp3_root / f"{canonical_id}.mp3"


def mp3_reference(
    entry_id: int | str,
    config: Real508StorageConfig,
) -> str:
    """Obtiene referencia local o URL pública parametrizable del MP3."""

    canonical_id = canonical_real508_id(entry_id)

    if config.public_mp3_base_url:
        base = config.public_mp3_base_url.rstrip("/")
        return f"{base}/{canonical_id}.mp3"

    return mp3_path(canonical_id, config).as_posix()


def multimedia_resources(
    entry_id: int | str,
    config: Real508StorageConfig,
) -> tuple[MultimediaResource, ...]:
    """Construye recursos compatibles con lexical_engine sin duplicar modelos."""

    canonical_id = canonical_real508_id(entry_id)

    return (
        MultimediaResource(
            resource_type="audio",
            language="pu",
            path=mp3_reference(canonical_id, config),
        ),
    )


def validate_inventory(
    config: Real508StorageConfig,
    *,
    require_wav: bool = True,
    require_mp3: bool = True,
) -> dict[str, object]:
    """Valida presencia física de la línea base sin modificar archivos."""

    missing_wav: list[str] = []
    missing_mp3: list[str] = []

    for number in range(REAL508_FIRST_ID, REAL508_LAST_ID + 1):
        entry_id = canonical_real508_id(number)

        if require_wav and not wav_path(entry_id, config).is_file():
            missing_wav.append(entry_id)

        if require_mp3 and not mp3_path(entry_id, config).is_file():
            missing_mp3.append(entry_id)

    return {
        "expected": REAL508_COUNT,
        "wav_missing": tuple(missing_wav),
        "mp3_missing": tuple(missing_mp3),
        "wav_valid": not missing_wav,
        "mp3_valid": not missing_mp3,
        "valid": not missing_wav and not missing_mp3,
    }


def build_media_manifest(
    entry_ids: Iterable[int | str],
    config: Real508StorageConfig,
) -> tuple[dict[str, str | None], ...]:
    """Construye manifiesto de referencias; no copia ni transforma audio."""

    result: list[dict[str, str | None]] = []

    for value in entry_ids:
        entry_id = canonical_real508_id(value)

        result.append(
            {
                "entry_id": entry_id,
                "media_type": "audio_puinave",
                "language": "pu",
                "path": mp3_reference(entry_id, config),
            }
        )

    return tuple(result)