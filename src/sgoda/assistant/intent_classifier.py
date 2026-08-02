"""Clasificador institucional de intenciones."""

from __future__ import annotations

import re
import unicodedata


def normalize_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.casefold())
    without_marks = "".join(
        char for char in normalized
        if not unicodedata.combining(char)
    )
    return re.sub(r"\s+", " ", without_marks).strip()


RULES: list[tuple[str, tuple[str, ...]]] = [
    (
        "platform_help",
        (
            "como uso",
            "como buscar",
            "como escuch",
            "como funciona",
            "ayuda",
            "donde encuentro",
        ),
    ),
    (
        "project_information",
        (
            "que es sgoda",
            "proyecto puinave",
            "objetivo del proyecto",
            "para que sirve",
        ),
    ),
    (
        "learning_activity",
        (
            "hazme una prueba",
            "quiero practicar",
            "quiero aprender",
            "palabras nuevas",
            "actividad",
        ),
    ),
    (
        "category_search",
        (
            "palabras relacionadas",
            "palabras de",
            "categoria",
            "animales",
            "plantas",
            "familia",
        ),
    ),
    (
        "lexical_search",
        (
            "como se dice",
            "que significa",
            "traduccion",
            "palabra",
            "en puinave",
            "en español",
            "en ingles",
        ),
    ),
]


def classify_intent(question: str) -> tuple[str, float]:
    normalized = normalize_text(question)

    for intent, patterns in RULES:
        if any(pattern in normalized for pattern in patterns):
            return intent, 0.92

    if len(normalized.split()) <= 3:
        return "lexical_search", 0.65

    return "unknown", 0.25