"""Integración REAL-508 con el modelo léxico y repositorio operativo SGODA.

Este módulo es una capa adaptadora. No modifica, copia ni transforma
los WAV/MP3 certificados de REAL-508.
"""

from __future__ import annotations

from dataclasses import asdict
from typing import Any, Iterable

from sgoda.integration.real508_adapter import (
    Real508StorageConfig,
    canonical_real508_id,
    multimedia_resources,
)
from sgoda.lexical_engine.models import LexicalEntry
from sgoda.operational_platform.database import OperationalRepository


def build_real508_lexical_entry(
    *,
    lexical_id: int | str,
    config: Real508StorageConfig,
    puinave: str = "",
    spanish: str = "",
    extra: dict[str, Any] | None = None,
) -> LexicalEntry:
    """Construye LexicalEntry usando exclusivamente su contrato canónico."""

    entry_id = canonical_real508_id(lexical_id)

    metadata: dict[str, Any] = {
        "dataset": "REAL-508",
        "source": "real508_adapter",
    }

    if extra:
        metadata.update(dict(extra))

    return LexicalEntry(
        entry_id=entry_id,
        puinave=str(puinave),
        spanish=str(spanish),
        multimedia=multimedia_resources(
            entry_id,
            config,
        ),
        metadata=metadata,
    )


def operational_record_from_entry(
    entry: LexicalEntry,
) -> dict[str, Any]:
    """Convierte LexicalEntry al contrato del repositorio operativo."""

    raw = asdict(entry)

    entry_id = str(raw.get("entry_id") or "").strip()

    if not entry_id:
        raise ValueError(
            "LexicalEntry no contiene entry_id."
        )

    multimedia = raw.pop("multimedia", ())
    raw["entry_id"] = entry_id

    return {
        "entry_id": entry_id,
        "lexical": raw,
        "multimedia": list(multimedia),
    }


def load_real508_into_operational_repository(
    *,
    repository: OperationalRepository,
    entries: Iterable[LexicalEntry],
) -> int:
    """Carga entradas y referencias multimedia sin tocar los audios."""

    total = 0

    for entry in entries:
        record = operational_record_from_entry(entry)

        repository.upsert_entry(
            record["lexical"]
        )

        for resource in record["multimedia"]:
            repository.attach_media(
                record["entry_id"],
                dict(resource),
            )

        total += 1

    return total


def real508_api_contract(
    *,
    repository: OperationalRepository,
    entry_id: int | str,
) -> dict[str, Any]:
    """Construye el contrato consumible por la capa API."""

    canonical_id = canonical_real508_id(entry_id)

    lexical = repository.get_entry(canonical_id)

    if lexical is None:
        return {
            "status": "not_found",
            "entry_id": canonical_id,
        }

    multimedia = repository.media_for(canonical_id)

    return {
        "status": "ok",
        "entry_id": canonical_id,
        "lexical": lexical,
        "multimedia": list(multimedia),
    }