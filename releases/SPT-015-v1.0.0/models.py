"""Modelos institucionales de SPT-015."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class AssessmentItem:
    item_id: str
    entry_id: str
    competency: str
    assessment_type: str
    difficulty: int
    prompt: str
    correct_answer: str
    options: tuple[str, ...] = ()
    media_resource_ids: tuple[str, ...] = ()
    validated: bool = False
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LearnerAttempt:
    learner_id: str
    item_id: str
    answer: str
    correct: bool
    score: float
    difficulty: int
    competency: str


@dataclass(frozen=True, slots=True)
class AssessmentCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AssessmentResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True