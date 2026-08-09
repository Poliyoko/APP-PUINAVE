"""SPT-023.2 - evaluacion contextual sin invencion."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


CONTEXT_FIELDS = (
    "spanish",
    "english",
    "italian",
    "category",
    "definition",
    "example",
)


@dataclass(frozen=True, slots=True)
class ContextAssessment:
    available_fields: tuple[str, ...]
    missing_fields: tuple[str, ...]
    evidence_count: int
    coverage: float
    status: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "available_fields": list(self.available_fields),
            "missing_fields": list(self.missing_fields),
            "evidence_count": self.evidence_count,
            "coverage": self.coverage,
            "status": self.status,
        }


def assess_context(
    result: dict[str, Any],
) -> ContextAssessment:
    metadata = result.get("metadata")

    if not isinstance(metadata, dict):
        metadata = {}

    available: list[str] = []
    missing: list[str] = []

    aliases = {
        "spanish": ("spanish", "espanol", "español"),
        "english": ("english", "ingles", "inglés"),
        "italian": ("italian", "italiano"),
        "category": (
            "category",
            "categoria",
            "categoria_principal",
        ),
        "definition": (
            "definition",
            "definicion",
            "significado",
        ),
        "example": (
            "example",
            "ejemplo",
            "usage_example",
        ),
    }

    for canonical in CONTEXT_FIELDS:
        values = aliases[canonical]

        present = any(
            str(metadata.get(key) or "").strip()
            for key in values
        )

        if present:
            available.append(canonical)
        else:
            missing.append(canonical)

    coverage = round(
        len(available) / len(CONTEXT_FIELDS),
        4,
    )

    if coverage >= 0.5:
        status = "SUFFICIENT"
    elif coverage > 0:
        status = "PARTIAL"
    else:
        status = "ABSENT"

    return ContextAssessment(
        available_fields=tuple(available),
        missing_fields=tuple(missing),
        evidence_count=len(available),
        coverage=coverage,
        status=status,
    )