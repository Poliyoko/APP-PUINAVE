"""Contratos consumibles por Flutter."""

from __future__ import annotations

from typing import Any


def lexical_card(
    entry: dict[str, Any],
    media: tuple[dict[str, Any], ...],
) -> dict[str, Any]:
    return {
        "entryId": entry["entry_id"],
        "languages": {
            "pu": entry.get("puinave", ""),
            "es": entry.get("spanish", ""),
            "en-US": entry.get("english_us", ""),
            "it": entry.get("italian", ""),
        },
        "category": entry.get("category", ""),
        "validated": bool(entry.get("validated", False)),
        "media": [
            {
                "type": (item.get("media_type") or item.get("resource_type") or ""),
                "uri": (item.get("uri") or item.get("path") or ""),
                "validated": bool(
                    item.get("validated", False)
                ),
                "autoplay": bool(
                    item.get("autoplay", False)
                ),
            }
            for item in media
        ],
        "noInvention": True,
    }


def health_contract(status: dict[str, Any]) -> dict[str, Any]:
    return {
        "status": "ok" if status.get("healthy") else "degraded",
        "component": "SPT-011",
        "version": "1.0.0",
        "details": status,
    }