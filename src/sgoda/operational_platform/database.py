"""Abstracción de persistencia operativa.

La versión 1.0.0 utiliza memoria local determinista y define el contrato
para PostgreSQL sin requerir un servidor durante las pruebas.
"""

from __future__ import annotations

from collections.abc import Iterable
from typing import Any


class OperationalRepository:
    def __init__(self) -> None:
        self._entries: dict[str, dict[str, Any]] = {}
        self._media: dict[str, list[dict[str, Any]]] = {}

    def upsert_entry(self, record: dict[str, Any]) -> None:
        entry_id = str(record.get("entry_id") or "").strip()

        if not entry_id:
            raise ValueError("entry_id es obligatorio.")

        self._entries[entry_id] = dict(record)

    def upsert_entries(
        self,
        records: Iterable[dict[str, Any]],
    ) -> None:
        for record in records:
            self.upsert_entry(record)

    def get_entry(
        self,
        entry_id: str,
    ) -> dict[str, Any] | None:
        value = self._entries.get(entry_id)
        return dict(value) if value is not None else None

    def all_entries(self) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(self._entries[key])
            for key in sorted(self._entries)
        )

    def attach_media(
        self,
        entry_id: str,
        media: dict[str, Any],
    ) -> None:
        if entry_id not in self._entries:
            raise KeyError(
                f"No existe el registro léxico: {entry_id}"
            )

        self._media.setdefault(entry_id, []).append(
            dict(media)
        )

    def media_for(
        self,
        entry_id: str,
    ) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(item)
            for item in self._media.get(entry_id, [])
        )

    def count(self) -> int:
        return len(self._entries)