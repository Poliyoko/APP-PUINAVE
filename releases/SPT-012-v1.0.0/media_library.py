"""Biblioteca multimedia validada."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


_ALLOWED = {
    "image",
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
    "audio_italian",
    "video",
}


class MediaLibrary:
    def __init__(self) -> None:
        self._resources: dict[str, list[dict[str, Any]]] = {}

    def load(self, path: str | Path) -> None:
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )
        resources = (
            payload.get("resources", [])
            if isinstance(payload, dict)
            else payload
        )

        if not isinstance(resources, list):
            raise ValueError(
                "El manifiesto multimedia debe contener una lista."
            )

        for item in resources:
            if not isinstance(item, dict):
                continue

            if not bool(item.get("validated", False)):
                continue

            entry_id = str(item.get("entry_id") or "").strip()
            media_type = str(
                item.get("media_type") or ""
            ).strip()
            uri = str(item.get("uri") or "").strip()

            if not entry_id or media_type not in _ALLOWED or not uri:
                continue

            self._resources.setdefault(entry_id, []).append(
                {
                    "entry_id": entry_id,
                    "media_type": media_type,
                    "uri": uri,
                    "validated": True,
                    "autoplay": bool(item.get("autoplay", False)),
                }
            )

    def for_entry(
        self,
        entry_id: str,
    ) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(item)
            for item in self._resources.get(entry_id, [])
        )