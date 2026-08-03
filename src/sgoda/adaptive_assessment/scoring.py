"""Cálculo de puntaje y dominio."""

from __future__ import annotations

from .models import LearnerAttempt


def normalize_answer(value: str) -> str:
    return " ".join(str(value or "").strip().casefold().split())


def score_answer(
    answer: str,
    correct_answer: str,
) -> tuple[bool, float]:
    correct = (
        normalize_answer(answer)
        == normalize_answer(correct_answer)
    )

    return correct, 1.0 if correct else 0.0


def mastery(
    attempts: tuple[LearnerAttempt, ...],
) -> float:
    if not attempts:
        return 0.0

    weighted_score = sum(
        item.score * max(item.difficulty, 1)
        for item in attempts
    )
    total_weight = sum(
        max(item.difficulty, 1)
        for item in attempts
    )

    return round(weighted_score / total_weight, 4)