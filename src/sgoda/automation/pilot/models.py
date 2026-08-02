"""Modelos del piloto controlado SPT-003C."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class AprobacionPiloto:
    approval_id: str
    provider: str
    approved_by: str
    approved_at_utc: str
    expires_at_utc: str
    administrative_approved: bool
    cultural_approved: bool
    privacy_approved: bool
    budget_approved: bool
    live_calls_authorized: bool
    allowed_job_types: list[str] = field(default_factory=list)
    max_jobs: int = 0
    max_cost_usd: float = 0.0


@dataclass(slots=True)
class DecisionPiloto:
    allowed: bool
    mode: str
    reasons: list[str] = field(default_factory=list)


@dataclass(slots=True)
class RegistroConsumo:
    provider: str
    job_type: str
    units: int
    estimated_cost_usd: float
    job_id: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class ResumenPiloto:
    provider: str
    mode: str
    requested_jobs: int
    authorized_jobs: int
    executed_jobs: int
    blocked_jobs: int
    estimated_cost_usd: float
    circuit_state: str
    approval_id: str | None