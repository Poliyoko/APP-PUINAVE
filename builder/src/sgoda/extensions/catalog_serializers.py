"""Serializadores del catálogo local."""

from __future__ import annotations

import json
from typing import Iterable

from .catalog_models import CatalogEntry, CatalogSnapshot


def entries_to_json(entries: Iterable[CatalogEntry]) -> str:
    return json.dumps(
        [entry.to_dict() for entry in entries],
        ensure_ascii=False,
        indent=2,
    )


def entries_to_text(entries: Iterable[CatalogEntry]) -> str:
    rows = list(entries)
    lines = ["Catálogo SGODA", "-" * 60]
    for entry in rows:
        state = "enabled" if entry.enabled else "disabled"
        lines.append(
            f"{entry.type}:{entry.name} {entry.version} "
            f"[{state}/{entry.status}]"
        )
    lines.extend(["-" * 60, f"Elementos: {len(rows)}"])
    return "\n".join(lines)


def snapshot_to_json(snapshot: CatalogSnapshot) -> str:
    return json.dumps(snapshot.to_dict(), ensure_ascii=False, indent=2)
