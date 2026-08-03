"""Modelos de evidencia de pruebas de SGD-114F."""

from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True, slots=True)
class TestEvidenceSummary:
    component: str
    scope: str
    executed: int
    passed: int
    failures: int
    errors: int
    skipped: int
    duration_seconds: float
    approved: bool
    source_report: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)