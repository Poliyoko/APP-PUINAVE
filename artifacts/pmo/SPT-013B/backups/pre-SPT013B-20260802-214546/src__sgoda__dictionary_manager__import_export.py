"""Importación y exportación JSON de SPT-013B."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import LexicalEntry, LexicalExample
from .validation import normalize_list, normalize_text


def entry_from_dict(payload: dict[str, Any]) -> LexicalEntry:
    examples = []

    for item in payload.get("examples", []) or []:
        if not isinstance(item, dict):
            continue

        examples.append(
            LexicalExample(
                language=normalize_text(item.get("language")),
                text=normalize_text(item.get("text")),
                translation=(
                    normalize_text(item.get("translation"))
                    or None
                ),
            )
        )

    return LexicalEntry(
        entry_id=normalize_text(payload.get("entry_id")),
        puinave=normalize_text(payload.get("puinave")),
        spanish=normalize_text(payload.get("spanish")),
        english_us=normalize_text(payload.get("english_us")),
        italian=normalize_text(payload.get("italian")),
        grammatical_category=normalize_text(
            payload.get("grammatical_category")
        ),
        lexical_family=normalize_text(
            payload.get("lexical_family")
        ),
        dialectal_variants=normalize_list(
            payload.get("dialectal_variants")
        ),
        synonyms=normalize_list(payload.get("synonyms")),
        antonyms=normalize_list(payload.get("antonyms")),
        examples=tuple(examples),
        validated=bool(payload.get("validated", False)),
        cultural_validation_required=bool(
            payload.get(
                "cultural_validation_required",
                True,
            )
        ),
        metadata=dict(payload.get("metadata") or {}),
    )


def entry_to_dict(entry: LexicalEntry) -> dict[str, Any]:
    return {
        "entry_id": entry.entry_id,
        "puinave": entry.puinave,
        "spanish": entry.spanish,
        "english_us": entry.english_us,
        "italian": entry.italian,
        "grammatical_category": entry.grammatical_category,
        "lexical_family": entry.lexical_family,
        "dialectal_variants": list(entry.dialectal_variants),
        "synonyms": list(entry.synonyms),
        "antonyms": list(entry.antonyms),
        "examples": [
            {
                "language": item.language,
                "text": item.text,
                "translation": item.translation,
            }
            for item in entry.examples
        ],
        "validated": entry.validated,
        "cultural_validation_required": (
            entry.cultural_validation_required
        ),
        "metadata": dict(entry.metadata),
    }


def load_entries(path: str | Path) -> tuple[LexicalEntry, ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )

    records = (
        payload.get("entries", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(records, list):
        raise ValueError(
            "El archivo debe contener una lista de entradas."
        )

    return tuple(
        entry_from_dict(item)
        for item in records
        if isinstance(item, dict)
    )


def export_entries(
    path: str | Path,
    entries: tuple[LexicalEntry, ...],
) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            {
                "schema": "SPT-013B",
                "version": "1.0.0",
                "entries": [
                    entry_to_dict(item)
                    for item in entries
                ],
            },
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )