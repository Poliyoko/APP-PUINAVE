"""Diccionario digital de SPT-012."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class DigitalDictionary:
    def __init__(self) -> None:
        self._entries: dict[str, dict[str, Any]] = {}

    def load(self, path: str | Path) -> None:
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )
        records = (
            payload.get("entries", [])
            if isinstance(payload, dict)
            else payload
        )

        if not isinstance(records, list):
            raise ValueError("El diccionario debe contener una lista.")

        for index, item in enumerate(records, start=1):
            if not isinstance(item, dict):
                continue

            if not bool(item.get("validated", False)):
                continue

            entry_id = str(
                item.get("entry_id")
                or item.get("id")
                or f"LEX-{index:06d}"
            ).strip()

            if not entry_id:
                continue

            self._entries[entry_id] = {
                "entry_id": entry_id,
                "puinave": str(item.get("puinave") or "").strip(),
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
                "category": str(
                    item.get("category") or ""
                ).strip(),
                "validated": True,
                "metadata": dict(item.get("metadata") or {}),
            }

    def get(self, entry_id: str) -> dict[str, Any] | None:
        value = self._entries.get(entry_id)
        return dict(value) if value is not None else None

    def all(self) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(self._entries[key])
            for key in sorted(self._entries)
        )

    def search(self, query: str) -> tuple[dict[str, Any], ...]:
        needle = str(query or "").strip().casefold()

        if not needle:
            return self.all()

        matches = []

        for entry in self.all():
            haystack = " ".join(
                [
                    entry.get("puinave", ""),
                    entry.get("spanish", ""),
                    entry.get("english_us", ""),
                    entry.get("italian", ""),
                    entry.get("category", ""),
                ]
            ).casefold()

            if needle in haystack:
                matches.append(entry)

        return tuple(matches)