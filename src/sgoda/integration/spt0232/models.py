"""Modelos institucionales de SPT-023.2."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class SemanticValidationResult:
    source_index: int
    puinave: str
    normalized_puinave: str
    lexical_hash: str
    input_status: str
    validation_status: str
    semantic_status: str
    semantic_query: str
    errors: tuple[str, ...] = ()
    semantic_candidates: tuple[dict[str, Any], ...] = ()
    suggestions: tuple[str, ...] = ()
    no_invention: bool = True
    downstream_allowed: bool = False
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "source_index": self.source_index,
            "puinave": self.puinave,
            "normalized_puinave": self.normalized_puinave,
            "lexical_hash": self.lexical_hash,
            "input_status": self.input_status,
            "validation_status": self.validation_status,
            "semantic_status": self.semantic_status,
            "semantic_query": self.semantic_query,
            "errors": list(self.errors),
            "semantic_candidates": [
                dict(item)
                for item in self.semantic_candidates
            ],
            "suggestions": list(self.suggestions),
            "no_invention": self.no_invention,
            "downstream_allowed": self.downstream_allowed,
            "metadata": dict(self.metadata),
        }