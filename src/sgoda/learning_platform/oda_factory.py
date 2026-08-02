"""Fábrica de Objetos Digitales de Aprendizaje."""

from __future__ import annotations

from typing import Any


def build_oda(
    entry: dict[str, Any],
    media: tuple[dict[str, Any], ...],
) -> dict[str, Any]:
    return {
        "odaId": f"ODA-{entry['entry_id']}",
        "entryId": entry["entry_id"],
        "title": entry.get("puinave", ""),
        "languages": {
            "pu": entry.get("puinave", ""),
            "es": entry.get("spanish", ""),
            "en-US": entry.get("english_us", ""),
            "it": entry.get("italian", ""),
        },
        "category": entry.get("category", ""),
        "media": [
            {
                "type": item["media_type"],
                "uri": item["uri"],
                "autoplay": bool(item.get("autoplay", False)),
            }
            for item in media
        ],
        "activities": [
            {
                "type": "listen",
                "instruction": "Escucha la pronunciación Puinave.",
            },
            {
                "type": "recognize",
                "instruction": "Relaciona la palabra con su imagen.",
            },
            {
                "type": "translate",
                "instruction": "Identifica su significado.",
            },
            {
                "type": "repeat",
                "instruction": "Repite la palabra en Puinave.",
            },
        ],
        "validated": bool(entry.get("validated", False)),
        "noInvention": True,
    }