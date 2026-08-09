"""SPT-023.2 - deteccion institucional de duplicados."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class DuplicateAssessment:
    duplicate: bool
    duplicate_type: str
    references: tuple[str, ...]
    blocked: bool

    def to_dict(self) -> dict[str, Any]:
        return {
            "duplicate": self.duplicate,
            "duplicate_type": self.duplicate_type,
            "references": list(self.references),
            "blocked": self.blocked,
        }


def _candidate_reference(
    candidate: dict[str, Any],
) -> str:
    for key in ("entry_id", "id", "lexical_id"):
        value = candidate.get(key)

        if value:
            return str(value)

    return "SEMANTIC_CANDIDATE"


def assess_duplicate(
    result: dict[str, Any],
    batch_normalized_counts: dict[str, int],
) -> DuplicateAssessment:
    normalized = str(
        result.get("normalized_puinave") or ""
    ).strip().casefold()

    if normalized and batch_normalized_counts.get(normalized, 0) > 1:
        return DuplicateAssessment(
            duplicate=True,
            duplicate_type="BATCH_DUPLICATE",
            references=(normalized,),
            blocked=True,
        )

    candidates = result.get("semantic_candidates") or []

    exact_references: list[str] = []

    for candidate in candidates:

        if not isinstance(candidate, dict):
            continue

        candidate_puinave = str(
            candidate.get("puinave") or ""
        ).strip().casefold()

        if normalized and candidate_puinave == normalized:
            exact_references.append(
                _candidate_reference(candidate)
            )

    if exact_references:
        return DuplicateAssessment(
            duplicate=True,
            duplicate_type="LEXICAL_EXISTING",
            references=tuple(
                sorted(set(exact_references))
            ),
            blocked=True,
        )

    return DuplicateAssessment(
        duplicate=False,
        duplicate_type="NONE",
        references=(),
        blocked=False,
    )


def build_batch_counts(
    results: list[dict[str, Any]],
) -> dict[str, int]:
    counts: dict[str, int] = {}

    for item in results:
        normalized = str(
            item.get("normalized_puinave") or ""
        ).strip().casefold()

        if not normalized:
            continue

        counts[normalized] = counts.get(normalized, 0) + 1

    return counts