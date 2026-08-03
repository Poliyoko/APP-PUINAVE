"""Tendencias y alertas pedagógicas."""

from __future__ import annotations

from .models import LearningEvent


def score_trend(
    events: tuple[LearningEvent, ...],
) -> str:
    scores = [
        float(event.score)
        for event in events
        if event.score is not None
    ]

    if len(scores) < 2:
        return "insufficient_data"

    if scores[-1] > scores[0]:
        return "improving"

    if scores[-1] < scores[0]:
        return "declining"

    return "stable"


def alerts(
    events: tuple[LearningEvent, ...],
) -> tuple[dict[str, str], ...]:
    scores = [
        float(event.score)
        for event in events
        if event.score is not None
    ]
    generated = []

    if len(scores) >= 2 and sum(scores) / len(scores) < 0.55:
        generated.append(
            {
                "code": "LOW_MASTERY",
                "severity": "warning",
                "message": "Dominio inferior al umbral institucional.",
            }
        )

    if not any(
        event.event_type == "resource_viewed"
        for event in events
    ):
        generated.append(
            {
                "code": "NO_MULTIMEDIA_USAGE",
                "severity": "info",
                "message": "No se registra uso de recursos multimedia.",
            }
        )

    return tuple(generated)