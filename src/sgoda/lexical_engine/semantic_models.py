"""Modelos semánticos de SPT-007B."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class SemanticRelation:
    source_id: str
    target_id: str
    relation_type: str
    weight: float = 1.0
    validated: bool = False
    cultural: bool = False
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class QueryExpansion:
    original: str
    normalized: str
    terms: tuple[str, ...]
    variants: tuple[str, ...]
    related_entry_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SemanticHit:
    entry_id: str
    lexical_score: float
    semantic_score: float
    relation_score: float
    final_score: float
    matched_terms: tuple[str, ...]
    relation_types: tuple[str, ...]
    explanation: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SemanticSearchResponse:
    query: str
    normalized_query: str
    total: int
    hits: tuple[SemanticHit, ...]
    suggestions: tuple[str, ...]
    no_invention: bool = True