"""Modelos canónicos del Motor Léxico Inteligente SPT-007A."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


SUPPORTED_LANGUAGES = ("pu", "es", "en-US", "it")


@dataclass(frozen=True, slots=True)
class MultimediaResource:
    resource_type: str
    language: str | None
    path: str
    validated: bool = False
    autoplay: bool = False
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LexicalEntry:
    entry_id: str
    puinave: str
    spanish: str = ""
    english_us: str = ""
    italian: str = ""
    category: str = ""
    validated: bool = False
    cultural_status: str = "pending"
    multimedia: tuple[MultimediaResource, ...] = ()
    metadata: dict[str, Any] = field(default_factory=dict)

    def text_by_language(self) -> dict[str, str]:
        return {
            "pu": self.puinave,
            "es": self.spanish,
            "en-US": self.english_us,
            "it": self.italian,
        }


@dataclass(frozen=True, slots=True)
class SearchQuery:
    text: str
    languages: tuple[str, ...] = SUPPORTED_LANGUAGES
    limit: int = 20
    include_unvalidated: bool = True
    category: str | None = None
    fuzzy: bool = True


@dataclass(frozen=True, slots=True)
class SearchHit:
    entry: LexicalEntry
    score: float
    match_type: str
    matched_language: str
    matched_text: str
    normalized_query: str
    normalized_text: str


@dataclass(frozen=True, slots=True)
class SearchResponse:
    query: SearchQuery
    total: int
    hits: tuple[SearchHit, ...]
    no_invention: bool = True