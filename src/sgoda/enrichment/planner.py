"""Detección de necesidades y planificación idempotente."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from .models import EnrichmentJob, EnrichmentNeed


def records_from_payload(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]

    if not isinstance(payload, dict):
        return []

    for key in (
        "records",
        "entries",
        "items",
        "palabras",
        "repository",
        "canonical_records",
    ):
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]

    for value in payload.values():
        if isinstance(value, list) and all(
            isinstance(item, dict) for item in value
        ):
            return list(value)

    return []


def field(record: dict[str, Any], *names: str) -> Any:
    for name in names:
        value = record.get(name)
        if value not in (None, ""):
            return value
    return None


def detect_needs(record: dict[str, Any]) -> list[EnrichmentNeed]:
    canonical_id = str(
        field(record, "canonical_id", "id", "lexical_id") or ""
    )
    spanish = field(
        record,
        "espanol",
        "español",
        "spanish",
        "traduccion_espanol",
    )
    english = field(
        record,
        "ingles",
        "inglés",
        "english",
        "traduccion_ingles",
    )

    needs: list[EnrichmentNeed] = []

    if not english:
        needs.append(
            EnrichmentNeed(
                canonical_id=canonical_id,
                resource_type="translation_en",
                priority=10,
                required=True,
                reason="Traducción inglesa ausente.",
            )
        )

    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="audio_es",
            priority=20,
            required=True,
            reason="Audio español requerido.",
        )
    )
    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="audio_en",
            priority=30,
            required=True,
            reason="Audio inglés requerido.",
        )
    )
    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="image",
            priority=40,
            required=True,
            reason="Apoyo visual requerido o no aplicable.",
        )
    )
    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="video",
            priority=50,
            required=False,
            reason="Video educativo opcional.",
        )
    )

    if not spanish:
        return [
            item for item in needs
            if item.resource_type not in {"audio_es", "translation_en"}
        ]

    return needs


def create_job(
    record: dict[str, Any],
    need: EnrichmentNeed,
) -> EnrichmentJob:
    canonical_id = need.canonical_id
    spanish = str(
        field(
            record,
            "espanol",
            "español",
            "spanish",
            "traduccion_espanol",
        )
        or ""
    )
    english = str(
        field(
            record,
            "ingles",
            "inglés",
            "english",
            "traduccion_ingles",
        )
        or ""
    )

    source_text = spanish
    target_language: str | None = None

    if need.resource_type == "translation_en":
        target_language = "en"
    elif need.resource_type == "audio_es":
        target_language = "es"
    elif need.resource_type == "audio_en":
        target_language = "en"
        source_text = english or spanish
    elif need.resource_type in {"image", "video"}:
        target_language = None

    raw = f"{canonical_id}|{need.resource_type}|{source_text}"
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:20]

    return EnrichmentJob(
        job_id=f"ENR-{digest.upper()}",
        canonical_id=canonical_id,
        resource_type=need.resource_type,
        source_text=source_text,
        target_language=target_language,
        metadata={
            "priority": need.priority,
            "required": need.required,
            "reason": need.reason,
        },
    )


def plan_repository(
    canonical_path: str | Path,
    *,
    limit: int | None = None,
) -> tuple[list[dict[str, Any]], list[EnrichmentJob]]:
    payload = json.loads(
        Path(canonical_path).read_text(encoding="utf-8")
    )
    records = records_from_payload(payload)

    if limit is not None:
        records = records[:limit]

    jobs: list[EnrichmentJob] = []
    seen: set[str] = set()

    for record in records:
        for need in detect_needs(record):
            job = create_job(record, need)
            if job.job_id not in seen:
                jobs.append(job)
                seen.add(job.job_id)

    jobs.sort(
        key=lambda item: (
            int(item.metadata["priority"]),
            item.canonical_id,
            item.resource_type,
        )
    )
    return records, jobs