from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class ReasoningQuestion:
    text: str
    start_node_id: str | None = None
    relation_filter: tuple[str, ...] = ()
    max_depth: int = 3


@dataclass(frozen=True, slots=True)
class ReasoningConclusion:
    subject_id: str
    relation_type: str
    object_id: str
    confidence: float
    explanation: str
    evidence: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class ReasoningResponse:
    question: ReasoningQuestion
    conclusions: tuple[ReasoningConclusion, ...]
    unresolved: bool
    no_invention: bool = True
    metadata: dict[str, Any] | None = None