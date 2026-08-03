
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


def build_decision_evidence(
    learner_id: str,
    source_components: tuple[str, ...],
    rationale: tuple[str, ...],
) -> dict[str, Any]:
    return {
        "learner_id": learner_id,
        "source_components": list(source_components),
        "rationale": list(rationale),
        "generated_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "explainable": True,
    }
