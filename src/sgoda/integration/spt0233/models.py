"""Modelos de resultado para SPT-023.3."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class CategoryAssignmentResult:
    source_index: int
    puinave: str
    lexical_hash: str
    input_decision: str
    assignment_status: str
    category_id: str | None = None
    category_name: str | None = None
    confidence: float = 0.0
    reasons: tuple[str, ...] = ()
    no_invention: bool = True
    requires_human_validation: bool = True
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "source_index": self.source_index,
            "puinave": self.puinave,
            "lexical_hash": self.lexical_hash,
            "input_decision": self.input_decision,
            "assignment_status": self.assignment_status,
            "category_id": self.category_id,
            "category_name": self.category_name,
            "confidence": self.confidence,
            "reasons": list(self.reasons),
            "no_invention": self.no_invention,
            "requires_human_validation": self.requires_human_validation,
            "metadata": dict(self.metadata),
        }
