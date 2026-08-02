from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True, slots=True)
class LearnerProfile:
    learner_id: str
    level: str = "beginner"
    preferred_language: str = "es"
    completed_entry_ids: tuple[str, ...] = ()
    interests: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class LearningActivity:
    activity_id: str
    activity_type: str
    title: str
    entry_ids: tuple[str, ...]
    instructions: str
    expected_answer: str | None = None
    metadata: dict = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LearningPath:
    path_id: str
    learner_id: str
    level: str
    activities: tuple[LearningActivity, ...]


@dataclass(frozen=True, slots=True)
class Feedback:
    correct: bool
    score: float
    message: str
    remediation: str = ""