
from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LearnerProfile:
    learner_id: str
    language: str = "es"
    level: str = "initial"
    strengths: tuple[str, ...] = ()
    needs: tuple[str, ...] = ()
    preferences: tuple[str, ...] = ()
    recent_scores: tuple[float, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["strengths"] = list(self.strengths)
        payload["needs"] = list(self.needs)
        payload["preferences"] = list(self.preferences)
        payload["recent_scores"] = list(self.recent_scores)
        return payload


@dataclass(frozen=True, slots=True)
class PedagogicalContext:
    objective: str
    knowledge_query: str
    activity_type: str = "practice"
    cultural_domain: str = "language"
    max_items: int = 5


@dataclass(frozen=True, slots=True)
class PedagogicalRecommendation:
    recommendation_id: str
    learner_id: str
    objective: str
    strategy: str
    difficulty: str
    content_ids: tuple[str, ...]
    explanation: str
    evidence: tuple[str, ...]
    safeguards: tuple[str, ...]
    confidence: float
    status: str = "proposed"
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["content_ids"] = list(self.content_ids)
        payload["evidence"] = list(self.evidence)
        payload["safeguards"] = list(self.safeguards)
        return payload
