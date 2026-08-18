"""Institutional progress measurement for SGODA-PUINAVE DMP.

This module separates:
- technical closure,
- individual progress,
- relative weight,
- weighted progress,
- phase progress,
- architecture progress,
- global project progress.

No project-specific weight policy is hard-coded here.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Mapping


CLOSED_VERIFIED = "CLOSED_VERIFIED"
IMPLEMENTED_NOT_CLOSED = "IMPLEMENTED_NOT_CLOSED"
DOCUMENT_ONLY = "DOCUMENT_ONLY"
HISTORICAL_REFERENCE = "HISTORICAL_REFERENCE"


@dataclass(frozen=True)
class ProgressInput:
    code: str
    classification: str
    family: str
    phase: str
    architecture: str
    weight: float
    individual_progress: float
    pending_for_closure: str = ""


@dataclass(frozen=True)
class ProgressResult:
    code: str
    classification: str
    family: str
    phase: str
    architecture: str
    weight: float
    individual_progress: float
    weighted_progress: float
    pending_for_closure: str


@dataclass(frozen=True)
class AggregateProgress:
    weight: float
    weighted_progress: float
    progress: float
    deliverables: int


@dataclass(frozen=True)
class ProjectProgress:
    global_progress: float
    total_weight: float
    weighted_progress: float
    deliverables: int
    closed_deliverables: int
    closed_percentage: float
    by_phase: Mapping[str, AggregateProgress]
    by_architecture: Mapping[str, AggregateProgress]


class ProgressValidationError(ValueError):
    """Raised when institutional progress input is invalid."""


def _validate_percentage(value: float, field: str) -> float:
    number = float(value)

    if number < 0.0 or number > 100.0:
        raise ProgressValidationError(
            f"{field} must be between 0 and 100"
        )

    return number


def _validate_weight(value: float) -> float:
    number = float(value)

    if number < 0.0:
        raise ProgressValidationError(
            "weight must be greater than or equal to zero"
        )

    return number


def measure(item: ProgressInput) -> ProgressResult:
    weight = _validate_weight(item.weight)

    progress = _validate_percentage(
        item.individual_progress,
        "individual_progress",
    )

    if (
        item.classification == CLOSED_VERIFIED
        and progress != 100.0
    ):
        raise ProgressValidationError(
            "CLOSED_VERIFIED requires 100 percent progress"
        )

    if (
        item.classification != CLOSED_VERIFIED
        and progress == 100.0
    ):
        raise ProgressValidationError(
            "100 percent progress requires CLOSED_VERIFIED"
        )

    return ProgressResult(
        code=item.code,
        classification=item.classification,
        family=item.family,
        phase=item.phase,
        architecture=item.architecture,
        weight=weight,
        individual_progress=progress,
        weighted_progress=weight * progress / 100.0,
        pending_for_closure=item.pending_for_closure,
    )


def _aggregate(
    rows: Iterable[ProgressResult],
    attribute: str,
) -> dict[str, AggregateProgress]:
    buckets: dict[str, list[ProgressResult]] = {}

    for row in rows:
        key = str(getattr(row, attribute)).strip() or "UNASSIGNED"
        buckets.setdefault(key, []).append(row)

    result: dict[str, AggregateProgress] = {}

    for key, items in sorted(buckets.items()):
        weight = sum(item.weight for item in items)

        weighted = sum(
            item.weighted_progress
            for item in items
        )

        progress = (
            weighted / weight * 100.0
            if weight > 0.0
            else 0.0
        )

        result[key] = AggregateProgress(
            weight=weight,
            weighted_progress=weighted,
            progress=progress,
            deliverables=len(items),
        )

    return result


def calculate_project_progress(
    inputs: Iterable[ProgressInput],
) -> ProjectProgress:
    rows = tuple(measure(item) for item in inputs)

    total_weight = sum(row.weight for row in rows)

    weighted_progress = sum(
        row.weighted_progress
        for row in rows
    )

    global_progress = (
        weighted_progress / total_weight * 100.0
        if total_weight > 0.0
        else 0.0
    )

    closed = sum(
        1
        for row in rows
        if row.classification == CLOSED_VERIFIED
    )

    closed_percentage = (
        closed / len(rows) * 100.0
        if rows
        else 0.0
    )

    return ProjectProgress(
        global_progress=global_progress,
        total_weight=total_weight,
        weighted_progress=weighted_progress,
        deliverables=len(rows),
        closed_deliverables=closed,
        closed_percentage=closed_percentage,
        by_phase=_aggregate(rows, "phase"),
        by_architecture=_aggregate(
            rows,
            "architecture",
        ),
    )