from __future__ import annotations


def classify_conversation_intent(text: str) -> str:
    normalized = str(text or "").strip().casefold()

    if any(
        token in normalized
        for token in ("aprender", "ejercicio", "practicar", "lección")
    ):
        return "tutor"

    if any(
        token in normalized
        for token in ("por qué", "explica", "relación", "cómo se relaciona")
    ):
        return "reasoning"

    if any(
        token in normalized
        for token in ("qué significa", "buscar", "palabra", "traducción")
    ):
        return "lexical"

    return "knowledge"