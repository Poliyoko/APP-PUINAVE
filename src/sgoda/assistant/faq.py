"""Preguntas frecuentes institucionales."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .intent_classifier import normalize_text


class FaqRepository:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        payload = json.loads(self.path.read_text(encoding="utf-8"))
        self.items: list[dict[str, Any]] = list(payload["items"])

    def search(self, question: str) -> dict[str, Any] | None:
        normalized = normalize_text(question)
        best: dict[str, Any] | None = None
        best_score = 0

        for item in self.items:
            keywords = [
                normalize_text(str(keyword))
                for keyword in item.get("keywords", [])
            ]
            score = sum(
                1 for keyword in keywords
                if keyword and keyword in normalized
            )
            if score > best_score:
                best = item
                best_score = score

        return best if best_score > 0 else None