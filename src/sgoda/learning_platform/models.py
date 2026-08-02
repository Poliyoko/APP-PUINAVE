"""Modelos canónicos de SPT-012."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LearningRequest:
    operation: str
    learner_id: str
    language: str = "es"
    entry_id: str | None = None
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LearningResponse:
    operation: str
    status: str
    data: dict[str, Any]
    sources: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    no_invention: bool = True


@dataclass(frozen=True, slots=True)
class LearningSession:
    session_id: str
    learner_id: str
    entry_id: str
    objective: str
    completed_steps: tuple[str, ...] = ()
    score: float = 0.0