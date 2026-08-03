"""Retroalimentación y recomendaciones."""

from __future__ import annotations


def build_feedback(
    correct: bool,
    mastery_score: float,
    competency: str,
) -> dict[str, object]:
    if correct:
        message = "Respuesta correcta."
    else:
        message = (
            "Respuesta incorrecta. Repase el recurso léxico "
            "y multimedia asociado."
        )

    if mastery_score >= 0.85:
        recommendation = "Avanzar a dificultad alta."
    elif mastery_score >= 0.55:
        recommendation = "Continuar con práctica intermedia."
    else:
        recommendation = "Reforzar fundamentos y repetir ODA."

    return {
        "message": message,
        "recommendation": recommendation,
        "competency": competency,
        "mastery": mastery_score,
    }