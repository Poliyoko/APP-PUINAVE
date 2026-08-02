"""Seguimiento de progreso local."""

from __future__ import annotations

from typing import Any


class ProgressTracker:
    def __init__(self) -> None:
        self._progress: dict[tuple[str, str], dict[str, Any]] = {}

    def record(
        self,
        learner_id: str,
        entry_id: str,
        completed_step: str,
        score: float | None = None,
    ) -> dict[str, Any]:
        key = (learner_id, entry_id)
        current = self._progress.setdefault(
            key,
            {
                "learnerId": learner_id,
                "entryId": entry_id,
                "completedSteps": [],
                "score": 0.0,
            },
        )

        if completed_step not in current["completedSteps"]:
            current["completedSteps"].append(completed_step)

        if score is not None:
            current["score"] = max(
                0.0,
                min(float(score), 100.0),
            )

        return {
            "learnerId": current["learnerId"],
            "entryId": current["entryId"],
            "completedSteps": list(current["completedSteps"]),
            "score": current["score"],
        }

    def get(
        self,
        learner_id: str,
        entry_id: str,
    ) -> dict[str, Any]:
        value = self._progress.get(
            (learner_id, entry_id),
            {
                "learnerId": learner_id,
                "entryId": entry_id,
                "completedSteps": [],
                "score": 0.0,
            },
        )

        return {
            "learnerId": value["learnerId"],
            "entryId": value["entryId"],
            "completedSteps": list(value["completedSteps"]),
            "score": value["score"],
        }