"""Modelos de analítica del aprendizaje."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LearningEvent:
    event_id: str
    learner_id: str
    event_type: str
    entry_id: str = ""
    competency: str = ""
    score: float | None = None
    duration_seconds: float | None = None
    resource_id: str = ""
    timestamp: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AnalyticsCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AnalyticsResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True