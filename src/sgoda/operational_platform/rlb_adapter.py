"""Adaptador del Repositorio Léxico Base."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_rlb(
    path: str | Path,
    validated_only: bool = True,
) -> tuple[dict[str, Any], ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )

    records = (
        payload.get("entries", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(records, list):
        raise ValueError("El RLB debe contener una lista.")

    normalized = []

    for index, item in enumerate(records, start=1):
        if not isinstance(item, dict):
            continue

        validated = bool(item.get("validated", False))

        if validated_only and not validated:
            continue

        entry_id = str(
            item.get("entry_id")
            or item.get("id")
            or f"LEX-{index:06d}"
        ).strip()

        if not entry_id:
            continue

        normalized.append(
            {
                "entry_id": entry_id,
                "puinave": str(
                    item.get("puinave") or ""
                ).strip(),
                "spanish": str(
                    item.get("spanish")
                    or item.get("espanol")
                    or ""
                ).strip(),
                "english_us": str(
                    item.get("english_us")
                    or item.get("english")
                    or ""
                ).strip(),
                "italian": str(
                    item.get("italian")
                    or item.get("italiano")
                    or ""
                ).strip(),
                "validated": validated,
                "category": str(
                    item.get("category") or ""
                ).strip(),
                "metadata": {
                    key: value
                    for key, value in item.items()
                    if key not in {
                        "entry_id",
                        "id",
                        "puinave",
                        "spanish",
                        "espanol",
                        "english_us",
                        "english",
                        "italian",
                        "italiano",
                        "validated",
                        "category",
                    }
                },
            }
        )

    return tuple(normalized)