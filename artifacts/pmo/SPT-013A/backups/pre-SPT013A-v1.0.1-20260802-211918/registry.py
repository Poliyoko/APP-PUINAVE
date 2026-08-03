"""Registro institucional de capacidades de la Fase IV.

SPT-012 es una dependencia externa de línea base ya implementada.
Las brechas internas se calculan únicamente entre SPT-013 y SPT-018.
"""

from __future__ import annotations

from .models import PhaseCapability


_PHASE_BASELINE_DEPENDENCIES = {
    "SPT-012",
}

_CAPABILITIES = (
    PhaseCapability(
        "SPT-013",
        "Gestor Institucional del Diccionario Digital",
        "dictionary",
        dependencies=("SPT-012",),
    ),
    PhaseCapability(
        "SPT-014",
        "Motor Multimedia Inteligente",
        "multimedia",
        dependencies=("SPT-013",),
    ),
    PhaseCapability(
        "SPT-015",
        "Motor de Evaluación Adaptativa",
        "assessment",
        dependencies=("SPT-013", "SPT-014"),
    ),
    PhaseCapability(
        "SPT-016",
        "Motor de Analítica del Aprendizaje",
        "analytics",
        dependencies=("SPT-015",),
    ),
    PhaseCapability(
        "SPT-017",
        "Centro de Conocimiento Puinave",
        "knowledge",
        dependencies=("SPT-013", "SPT-014"),
    ),
    PhaseCapability(
        "SPT-018",
        "IA Pedagógica SGODA",
        "pedagogical_ai",
        dependencies=(
            "SPT-013",
            "SPT-014",
            "SPT-015",
            "SPT-016",
            "SPT-017",
        ),
    ),
)


def phase_capabilities() -> tuple[PhaseCapability, ...]:
    return _CAPABILITIES


def baseline_dependencies() -> tuple[str, ...]:
    return tuple(sorted(_PHASE_BASELINE_DEPENDENCIES))


def dependency_gaps() -> tuple[dict[str, str], ...]:
    internal_codes = {item.code for item in _CAPABILITIES}
    accepted_codes = internal_codes | _PHASE_BASELINE_DEPENDENCIES
    gaps = []

    for item in _CAPABILITIES:
        for dependency in item.dependencies:
            if dependency not in accepted_codes:
                gaps.append(
                    {
                        "source": item.code,
                        "target": dependency,
                    }
                )

    return tuple(gaps)