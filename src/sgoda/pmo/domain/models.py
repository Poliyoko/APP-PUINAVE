"""Modelo único del proyecto para PMO Digital.

Este módulo implementa la fuente de datos única desde la que se generan
Dashboard, DMP, informes, presentación institucional y documento técnico.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field, replace
from datetime import UTC, datetime
from typing import Any, Self

from .enums import ArtifactType, KpiState, PmoStatus, RiskLevel
from .identifiers import normalize_identifier


def utc_now() -> str:
    return datetime.now(UTC).isoformat()


@dataclass(frozen=True, slots=True, kw_only=True)
class PmoEntity:
    identifier: str
    name: str
    description: str = ""
    created_at: str = ""
    updated_at: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        object.__setattr__(self, "identifier", normalize_identifier(self.identifier))
        clean_name = self.name.strip()
        if not clean_name:
            raise ValueError("El nombre no puede estar vacío")
        object.__setattr__(self, "name", clean_name)
        now = utc_now()
        if not self.created_at:
            object.__setattr__(self, "created_at", now)
        if not self.updated_at:
            object.__setattr__(self, "updated_at", now)

    def with_changes(self, **changes: Any) -> Self:
        return replace(self, updated_at=utc_now(), **changes)

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Project(PmoEntity):
    purpose: str = ""
    status: PmoStatus = PmoStatus.IN_PROGRESS
    repository_url: str = ""
    director: str = ""
    current_hito: str = ""
    baseline_document: str = ""

    def to_dict(self) -> dict[str, Any]:
        payload = super().to_dict()
        payload["status"] = self.status.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Deliverable(PmoEntity):
    code: str
    executive_name: str
    purpose: str
    benefit: str
    status: PmoStatus
    progress: float
    evidence: str = ""
    products: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        super(Deliverable, self).__post_init__()
        object.__setattr__(self, "code", normalize_identifier(self.code))
        if not 0 <= self.progress <= 100:
            raise ValueError("El avance debe estar entre 0 y 100")
        object.__setattr__(self, "products", tuple(self.products))

    def to_dict(self) -> dict[str, Any]:
        payload = super().to_dict()
        payload["status"] = self.status.value
        payload["products"] = list(self.products)
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Risk(PmoEntity):
    code: str
    level: RiskLevel
    probability: float
    impact: float
    mitigation: str

    def __post_init__(self) -> None:
        super(Risk, self).__post_init__()
        object.__setattr__(self, "code", normalize_identifier(self.code))
        for field_name, value in (("probability", self.probability), ("impact", self.impact)):
            if not 0 <= value <= 1:
                raise ValueError(f"{field_name} debe estar entre 0 y 1")

    def to_dict(self) -> dict[str, Any]:
        payload = super().to_dict()
        payload["level"] = self.level.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Kpi(PmoEntity):
    code: str
    value: float
    target: float
    unit: str
    state: KpiState

    def __post_init__(self) -> None:
        super(Kpi, self).__post_init__()
        object.__setattr__(self, "code", normalize_identifier(self.code))

    def to_dict(self) -> dict[str, Any]:
        payload = super().to_dict()
        payload["state"] = self.state.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Milestone(PmoEntity):
    code: str
    status: PmoStatus

    def __post_init__(self) -> None:
        super(Milestone, self).__post_init__()
        object.__setattr__(self, "code", normalize_identifier(self.code))

    def to_dict(self) -> dict[str, Any]:
        payload = super().to_dict()
        payload["status"] = self.status.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class GeneratedArtifact(PmoEntity):
    artifact_type: ArtifactType
    path: str
    source_model_version: str

    def to_dict(self) -> dict[str, Any]:
        payload = super().to_dict()
        payload["artifact_type"] = self.artifact_type.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class ProjectModel:
    schema_version: str
    project: Project
    deliverables: tuple[Deliverable, ...]
    risks: tuple[Risk, ...] = ()
    kpis: tuple[Kpi, ...] = ()
    milestones: tuple[Milestone, ...] = ()
    generated_at: str = field(default_factory=utc_now)

    @property
    def total_deliverables(self) -> int:
        return len(self.deliverables)

    @property
    def closed_deliverables(self) -> int:
        return sum(1 for item in self.deliverables if item.status in {PmoStatus.COMPLETED, PmoStatus.COMPLETED_DECLARED, PmoStatus.COMPLETED_VERIFIED})

    @property
    def average_progress(self) -> float:
        if not self.deliverables:
            return 0.0
        return round(sum(item.progress for item in self.deliverables) / len(self.deliverables), 2)

    @property
    def active_risks(self) -> int:
        return len(self.risks)

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "generated_at": self.generated_at,
            "project": self.project.to_dict(),
            "deliverables": [item.to_dict() for item in self.deliverables],
            "risks": [item.to_dict() for item in self.risks],
            "kpis": [item.to_dict() for item in self.kpis],
            "milestones": [item.to_dict() for item in self.milestones],
            "summary": {
                "total_deliverables": self.total_deliverables,
                "closed_deliverables": self.closed_deliverables,
                "average_progress": self.average_progress,
                "active_risks": self.active_risks,
            },
        }
