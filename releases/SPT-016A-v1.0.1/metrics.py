"""Cálculo de métricas educativas."""

from __future__ import annotations

from .models import LearningEvent


def scored_events(
    events: tuple[LearningEvent, ...],
) -> tuple[LearningEvent, ...]:
    return tuple(
        event
        for event in events
        if event.score is not None
    )


def mastery(
    events: tuple[LearningEvent, ...],
) -> float:
    scored = scored_events(events)

    if not scored:
        return 0.0

    return round(
        sum(float(event.score) for event in scored)
        / len(scored),
        4,
    )


def engagement(
    events: tuple[LearningEvent, ...],
) -> dict[str, float | int]:
    durations = [
        float(event.duration_seconds)
        for event in events
        if event.duration_seconds is not None
    ]

    return {
        "events": len(events),
        "duration_seconds": round(sum(durations), 4),
        "resource_views": sum(
            1
            for event in events
            if event.event_type == "resource_viewed"
        ),
        "assessments": sum(
            1
            for event in events
            if event.event_type == "assessment_completed"
        ),
    }


def progress(
    events: tuple[LearningEvent, ...],
) -> dict[str, float | int]:
    return {
        "mastery": mastery(events),
        **engagement(events),
    }