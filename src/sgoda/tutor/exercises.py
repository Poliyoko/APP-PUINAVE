from __future__ import annotations

from .models import Feedback, LearningActivity


def evaluate_answer(
    activity: LearningActivity,
    answer: str,
) -> Feedback:
    expected = (activity.expected_answer or "").strip().casefold()
    provided = str(answer or "").strip().casefold()

    if not expected:
        return Feedback(
            correct=False,
            score=0.0,
            message="La actividad no tiene respuesta validada.",
            remediation="Solicite revisión pedagógica.",
        )

    correct = provided == expected

    return Feedback(
        correct=correct,
        score=1.0 if correct else 0.0,
        message=(
            "Respuesta correcta."
            if correct
            else "Respuesta todavía no correcta."
        ),
        remediation=(
            ""
            if correct
            else "Vuelva a escuchar el audio y revise la ficha léxica."
        ),
    )


def build_multiple_choice(
    activity: LearningActivity,
    distractors: tuple[str, ...],
) -> dict:
    expected = activity.expected_answer or ""
    options = tuple(
        sorted(
            {
                expected,
                *(
                    item
                    for item in distractors
                    if str(item).strip()
                ),
            }
        )
    )

    return {
        "activity_id": activity.activity_id,
        "question": activity.instructions,
        "options": list(options),
        "answer": expected,
    }