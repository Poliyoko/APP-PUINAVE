"""Selección adaptativa de dificultad e ítems."""

from __future__ import annotations

from .models import AssessmentItem, LearnerAttempt
from .scoring import mastery


def recommended_difficulty(
    attempts: tuple[LearnerAttempt, ...],
) -> int:
    level = mastery(attempts)

    if level >= 0.85:
        return 3

    if level >= 0.55:
        return 2

    return 1


def select_next_item(
    items: tuple[AssessmentItem, ...],
    attempts: tuple[LearnerAttempt, ...],
) -> AssessmentItem | None:
    if not items:
        return None

    attempted_ids = {item.item_id for item in attempts}
    target = recommended_difficulty(attempts)

    candidates = [
        item
        for item in items
        if item.validated and item.item_id not in attempted_ids
    ]

    if not candidates:
        candidates = [
            item for item in items if item.validated
        ]

    if not candidates:
        return None

    return sorted(
        candidates,
        key=lambda item: (
            abs(item.difficulty - target),
            item.item_id,
        ),
    )[0]