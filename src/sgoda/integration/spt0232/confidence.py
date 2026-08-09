"""SPT-023.2 - evaluacion deterministica de confianza."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .context import ContextAssessment
from .duplicates import DuplicateAssessment


@dataclass(frozen=True, slots=True)
class ConfidenceAssessment:
    score: float
    level: str
    threshold: float
    factors: dict[str, float]

    def to_dict(self) -> dict[str, Any]:
        return {
            "score": self.score,
            "level": self.level,
            "threshold": self.threshold,
            "factors": dict(self.factors),
        }


def _semantic_score(
    result: dict[str, Any],
) -> float:
    candidates = result.get("semantic_candidates") or []

    scores: list[float] = []

    for candidate in candidates:

        if not isinstance(candidate, dict):
            continue

        value = candidate.get("final_score")

        try:
            numeric = float(value)
        except (TypeError, ValueError):
            continue

        numeric = max(0.0, min(100.0, numeric))
        scores.append(numeric / 100.0)

    if not scores:
        return 0.0

    return max(scores)


def assess_confidence(
    result: dict[str, Any],
    duplicate: DuplicateAssessment,
    context: ContextAssessment,
    threshold: float = 0.70,
) -> ConfidenceAssessment:
    validation_status = str(
        result.get("validation_status") or ""
    )

    validation_factor = (
        1.0
        if validation_status in {
            "VALIDATED",
            "VALIDATED_NO_MATCH",
        }
        else 0.0
    )

    semantic_factor = _semantic_score(result)
    context_factor = context.coverage
    duplicate_factor = 0.0 if duplicate.blocked else 1.0

    score = (
        validation_factor * 0.30
        + semantic_factor * 0.40
        + context_factor * 0.15
        + duplicate_factor * 0.15
    )

    score = round(
        max(0.0, min(1.0, score)),
        4,
    )

    if score >= 0.85:
        level = "HIGH"
    elif score >= threshold:
        level = "MEDIUM"
    else:
        level = "LOW"

    return ConfidenceAssessment(
        score=score,
        level=level,
        threshold=threshold,
        factors={
            "validation": round(validation_factor, 4),
            "semantic": round(semantic_factor, 4),
            "context": round(context_factor, 4),
            "duplicate_clearance": round(
                duplicate_factor,
                4,
            ),
        },
    )