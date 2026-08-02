"""Acceso seguro al conocimiento institucional validado."""

from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path
from typing import Any


def _normalize(value: Any) -> str:
    text = unicodedata.normalize(
        "NFKD",
        str(value or "").casefold(),
    )
    text = "".join(
        char for char in text
        if not unicodedata.combining(char)
    )
    return re.sub(r"\s+", " ", text).strip()


def _records_from_payload(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]

    if not isinstance(payload, dict):
        return []

    for key in (
        "records",
        "entries",
        "items",
        "palabras",
        "repository",
        "canonical_records",
        "objetos_digitales_aprendizaje",
        "odas",
    ):
        value = payload.get(key)
        if isinstance(value, list):
            return [
                item for item in value
                if isinstance(item, dict)
            ]

    for value in payload.values():
        if isinstance(value, list) and all(
            isinstance(item, dict) for item in value
        ):
            return list(value)

    return []


class KnowledgeRepository:
    def __init__(
        self,
        *,
        canonical_path: str | Path,
        oda_path: str | Path,
    ) -> None:
        self.canonical_path = Path(canonical_path)
        self.oda_path = Path(oda_path)

        canonical_payload = json.loads(
            self.canonical_path.read_text(encoding="utf-8")
        )
        oda_payload = json.loads(
            self.oda_path.read_text(encoding="utf-8")
        )

        self.canonical_records = _records_from_payload(
            canonical_payload
        )
        self.oda_records = _records_from_payload(oda_payload)

    @staticmethod
    def _field(
        record: dict[str, Any],
        *names: str,
    ) -> Any:
        for name in names:
            value = record.get(name)
            if value not in (None, ""):
                return value
        return None

    def search_lexical(
        self,
        term: str,
        *,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        normalized_term = _normalize(term)
        if not normalized_term:
            return []

        scored: list[tuple[int, dict[str, Any]]] = []

        for record in self.canonical_records:
            puinave = self._field(
                record,
                "puinave",
                "palabra_puinave",
                "termino_puinave",
                "word_puinave",
            )
            spanish = self._field(
                record,
                "espanol",
                "español",
                "traduccion_espanol",
                "traducción_español",
                "spanish",
            )
            english = self._field(
                record,
                "ingles",
                "inglés",
                "traduccion_ingles",
                "traducción_inglés",
                "english",
            )
            category = self._field(
                record,
                "categoria",
                "categoría",
                "category",
                "campo_semantico",
            )

            values = [
                _normalize(puinave),
                _normalize(spanish),
                _normalize(english),
                _normalize(category),
            ]

            score = 0
            for value in values:
                if not value:
                    continue
                if normalized_term == value:
                    score = max(score, 100)
                elif normalized_term in value:
                    score = max(score, 70)
                elif value in normalized_term:
                    score = max(score, 50)

            if score > 0:
                scored.append(
                    (
                        score,
                        {
                            "canonical_id": self._field(
                                record,
                                "canonical_id",
                                "id",
                                "lexical_id",
                            ),
                            "puinave": puinave,
                            "spanish": spanish,
                            "english": english,
                            "category": category,
                            "raw": record,
                        },
                    )
                )

        scored.sort(
            key=lambda item: (
                -item[0],
                _normalize(item[1].get("puinave")),
            )
        )
        return [item[1] for item in scored[:limit]]

    def search_category(
        self,
        category: str,
        *,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        return self.search_lexical(category, limit=limit)

    def find_oda(
        self,
        canonical_id: str | None,
    ) -> dict[str, Any] | None:
        if not canonical_id:
            return None

        normalized = _normalize(canonical_id)

        for record in self.oda_records:
            value = self._field(
                record,
                "canonical_id",
                "lexical_id",
                "source_id",
            )
            if _normalize(value) == normalized:
                return record

        return None