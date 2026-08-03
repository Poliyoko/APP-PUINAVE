"""Recomendaciones para tutor e IA pedagógica."""

from __future__ import annotations

from .metrics import mastery
from .models import LearningEvent
from .trends import score_trend


def recommend(
    events: tuple[LearningEvent, ...],
) -> dict[str, object]:
    level = mastery(events)
    trend = score_trend(events)

    if level >= 0.85:
        action = "advance"
        message = "Avanzar a actividades de mayor dificultad."
    elif level >= 0.55:
        action = "practice"
        message = "Continuar práctica guiada."
    else:
        action = "reinforce"
        message = "Reforzar léxico y multimedia antes de evaluar."

    return {
        "action": action,
        "message": message,
        "mastery": level,
        "trend": trend,
        "target_components": ["SPT-008", "SPT-018"],
        "no_invention": True,
    }