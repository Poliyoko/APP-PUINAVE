"""Modelos del orquestador multimedia SPT-003A."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class TrabajoMultimedia:
    job_id: str
    resource_id: str
    oda_id: str
    canonical_id: str
    job_type: str
    language: str | None
    status: str = "pending"
    priority: int = 100
    attempt_count: int = 0
    max_attempts: int = 3
    provider: str | None = None
    payload: dict[str, Any] = field(default_factory=dict)
    result: dict[str, Any] = field(default_factory=dict)
    error: str | None = None
    available_at_utc: str | None = None
    lease_until_utc: str | None = None
    created_at_utc: str | None = None
    updated_at_utc: str | None = None


@dataclass(slots=True)
class ResumenPlanificacion:
    resources_seen: int
    jobs_planned: int
    jobs_inserted: int
    jobs_existing: int
    by_type: dict[str, int]
    unsupported_resources: int