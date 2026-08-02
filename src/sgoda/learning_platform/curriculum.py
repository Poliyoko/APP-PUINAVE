"""Rutas de aprendizaje."""

from __future__ import annotations

from typing import Any


def build_learning_path(
    entry: dict[str, Any],
    level: str = "initial",
) -> dict[str, Any]:
    supported = {
        "initial",
        "basic",
        "intermediate",
    }
    normalized = str(level or "initial").casefold()

    if normalized not in supported:
        normalized = "initial"

    steps = [
        {
            "stepId": "observe",
            "title": "Observar",
            "objective": "Reconocer la ficha léxica.",
        },
        {
            "stepId": "listen",
            "title": "Escuchar",
            "objective": "Escuchar la pronunciación disponible.",
        },
        {
            "stepId": "associate",
            "title": "Asociar",
            "objective": "Relacionar palabra, significado e imagen.",
        },
        {
            "stepId": "practice",
            "title": "Practicar",
            "objective": "Resolver una actividad breve.",
        },
        {
            "stepId": "evaluate",
            "title": "Evaluar",
            "objective": "Comprobar la comprensión.",
        },
    ]

    return {
        "pathId": f"PATH-{entry['entry_id']}-{normalized}",
        "entryId": entry["entry_id"],
        "level": normalized,
        "steps": steps,
        "estimatedMinutes": 10,
        "noInvention": True,
    }