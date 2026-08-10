"""Catalogo deterministico de categorias existentes para SPT-023.3."""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from typing import Any, Iterable


def _normalize(value: object) -> str:
    text = str(value or "").strip().casefold()
    text = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in text if not unicodedata.combining(ch))


@dataclass(frozen=True)
class CategoryDefinition:
    category_id: str
    name: str
    aliases: tuple[str, ...] = ()
    keywords: tuple[str, ...] = ()
    metadata: dict[str, Any] | None = None


class CategoryCatalog:
    """Solo contiene categorias institucionales ya existentes.

    La Capa 1 no crea categorias nuevas. La asignacion se limita a
    evidencia textual ya presente en la salida semantica SPT-023.2.
    """

    def __init__(self, categories: Iterable[dict[str, Any]]) -> None:
        definitions: list[CategoryDefinition] = []
        seen_ids: set[str] = set()

        for item in categories:
            if not isinstance(item, dict):
                raise TypeError("Cada categoria debe ser un objeto dict.")

            category_id = str(
                item.get("id") or item.get("category_id") or ""
            ).strip()
            name = str(item.get("name") or item.get("nombre") or "").strip()

            if not category_id or not name:
                raise ValueError("Cada categoria requiere id y name.")

            if category_id in seen_ids:
                raise ValueError(
                    f"Categoria duplicada en catalogo: {category_id}"
                )

            seen_ids.add(category_id)
            aliases = tuple(
                str(value).strip()
                for value in item.get("aliases", ())
                if str(value).strip()
            )
            keywords = tuple(
                str(value).strip()
                for value in item.get("keywords", ())
                if str(value).strip()
            )

            definitions.append(
                CategoryDefinition(
                    category_id=category_id,
                    name=name,
                    aliases=aliases,
                    keywords=keywords,
                    metadata=dict(item.get("metadata") or {}),
                )
            )

        self._categories = tuple(definitions)

    @property
    def categories(self) -> tuple[CategoryDefinition, ...]:
        return self._categories

    def rank(self, evidence: Iterable[str]) -> list[tuple[float, CategoryDefinition, str]]:
        normalized_evidence = {
            _normalize(value)
            for value in evidence
            if _normalize(value)
        }

        ranked: list[tuple[float, CategoryDefinition, str]] = []

        for category in self._categories:
            exact_terms = {
                _normalize(category.name),
                *(_normalize(value) for value in category.aliases),
            }
            keyword_terms = {
                _normalize(value)
                for value in category.keywords
                if _normalize(value)
            }

            exact_hit = sorted(normalized_evidence.intersection(exact_terms))
            if exact_hit:
                ranked.append((1.0, category, f"exact:{exact_hit[0]}"))
                continue

            keyword_hit = sorted(
                value
                for value in normalized_evidence
                for keyword in keyword_terms
                if keyword and (
                    value == keyword
                    or keyword in value.split()
                    or keyword in value
                )
            )

            if keyword_hit:
                ranked.append((0.85, category, f"keyword:{keyword_hit[0]}"))

        ranked.sort(
            key=lambda item: (
                -item[0],
                item[1].category_id,
            )
        )
        return ranked
