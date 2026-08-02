"""Repositorio léxico de solo lectura compatible con RLB JSON."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import LexicalEntry, MultimediaResource


def _first(payload: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = payload.get(key)

        if value is not None and str(value).strip():
            return str(value).strip()

    return ""


def _bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value

    return str(value).strip().casefold() in {
        "1",
        "true",
        "yes",
        "si",
        "sí",
        "validated",
        "approved",
        "aprobado",
    }


def _multimedia(payload: dict[str, Any]) -> tuple[MultimediaResource, ...]:
    resources: list[MultimediaResource] = []

    raw = payload.get("multimedia") or payload.get("resources") or []

    if isinstance(raw, dict):
        raw = [
            {
                "resource_type": key,
                "path": value,
            }
            for key, value in raw.items()
            if value
        ]

    if isinstance(raw, list):
        for item in raw:
            if not isinstance(item, dict):
                continue

            path = _first(item, "path", "url", "file")

            if not path:
                continue

            resources.append(
                MultimediaResource(
                    resource_type=_first(
                        item,
                        "resource_type",
                        "type",
                        "kind",
                    )
                    or "unknown",
                    language=_first(
                        item,
                        "language",
                        "locale",
                    )
                    or None,
                    path=path,
                    validated=_bool(
                        item.get("validated", False)
                    ),
                    autoplay=_bool(
                        item.get("autoplay", False)
                    ),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key
                        not in {
                            "resource_type",
                            "type",
                            "kind",
                            "language",
                            "locale",
                            "path",
                            "url",
                            "file",
                            "validated",
                            "autoplay",
                        }
                    },
                )
            )

    direct_fields = (
        ("audio_puinave", "audio", "pu"),
        ("audio_spanish", "audio", "es"),
        ("audio_es", "audio", "es"),
        ("audio_english", "audio", "en-US"),
        ("audio_en", "audio", "en-US"),
        ("audio_italian", "audio", "it"),
        ("audio_it", "audio", "it"),
        ("image", "image", None),
        ("imagen", "image", None),
        ("video", "video", None),
    )

    known = {(item.resource_type, item.language, item.path) for item in resources}

    for field_name, resource_type, language in direct_fields:
        value = payload.get(field_name)

        if value and (
            resource_type,
            language,
            str(value),
        ) not in known:
            resources.append(
                MultimediaResource(
                    resource_type=resource_type,
                    language=language,
                    path=str(value),
                    validated=_bool(
                        payload.get(f"{field_name}_validated", False)
                    ),
                    autoplay=(
                        resource_type == "audio"
                        and language in {"es", "en-US", "it"}
                    ),
                )
            )

    return tuple(resources)


def entry_from_dict(
    payload: dict[str, Any],
    index: int,
) -> LexicalEntry:
    entry_id = _first(
        payload,
        "entry_id",
        "id",
        "lexical_id",
        "codigo",
        "code",
    ) or f"LEX-{index:06d}"

    puinave = _first(
        payload,
        "puinave",
        "native",
        "word",
        "palabra_puinave",
        "termino_puinave",
    )

    spanish = _first(
        payload,
        "spanish",
        "es",
        "espanol",
        "español",
        "traduccion_es",
    )

    english = _first(
        payload,
        "english_us",
        "english",
        "en-US",
        "en",
        "traduccion_en",
    )

    italian = _first(
        payload,
        "italian",
        "it",
        "italiano",
        "traduccion_it",
    )

    return LexicalEntry(
        entry_id=entry_id,
        puinave=puinave,
        spanish=spanish,
        english_us=english,
        italian=italian,
        category=_first(
            payload,
            "category",
            "categoria",
            "class",
        ),
        validated=_bool(
            payload.get(
                "validated",
                payload.get("validado", False),
            )
        ),
        cultural_status=_first(
            payload,
            "cultural_status",
            "estado_cultural",
        )
        or "pending",
        multimedia=_multimedia(payload),
        metadata={
            key: value
            for key, value in payload.items()
            if key
            not in {
                "entry_id",
                "id",
                "lexical_id",
                "codigo",
                "code",
                "puinave",
                "native",
                "word",
                "palabra_puinave",
                "termino_puinave",
                "spanish",
                "es",
                "espanol",
                "español",
                "traduccion_es",
                "english_us",
                "english",
                "en-US",
                "en",
                "traduccion_en",
                "italian",
                "it",
                "italiano",
                "traduccion_it",
                "category",
                "categoria",
                "class",
                "validated",
                "validado",
                "cultural_status",
                "estado_cultural",
                "multimedia",
                "resources",
            }
        },
    )


class LexicalRepository:
    def __init__(self, entries: list[LexicalEntry]) -> None:
        self._entries = tuple(entries)

    @classmethod
    def from_json(cls, path: str | Path) -> "LexicalRepository":
        target = Path(path)
        payload = json.loads(
            target.read_text(encoding="utf-8-sig")
        )

        if isinstance(payload, dict):
            raw_entries = (
                payload.get("entries")
                or payload.get("records")
                or payload.get("words")
                or payload.get("palabras")
                or []
            )
        else:
            raw_entries = payload

        if not isinstance(raw_entries, list):
            raise ValueError(
                "El archivo RLB debe contener una lista de registros."
            )

        entries = [
            entry_from_dict(item, index)
            for index, item in enumerate(raw_entries, start=1)
            if isinstance(item, dict)
        ]

        return cls(entries)

    @classmethod
    def from_records(
        cls,
        records: list[dict[str, Any]],
    ) -> "LexicalRepository":
        return cls(
            [
                entry_from_dict(item, index)
                for index, item in enumerate(records, start=1)
            ]
        )

    def all(self) -> tuple[LexicalEntry, ...]:
        return self._entries

    def __len__(self) -> int:
        return len(self._entries)