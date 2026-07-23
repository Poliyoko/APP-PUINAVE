"""Modelo de dominio inicial del subsistema DMP-SGODA."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field, replace
from datetime import UTC, date, datetime
from typing import Any, Self

from .enums import ChangeStatus, EvidenceType, RiskLevel, WorkStatus
from .identifiers import normalize_identifier


def utc_now() -> str:
    return datetime.now(UTC).isoformat()


@dataclass(frozen=True, slots=True, kw_only=True)
class DmpEntity:
    """Entidad base inmutable y serializable del DMP."""

    identifier: str
    name: str
    description: str = ""
    status: WorkStatus = WorkStatus.PLANNED
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

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["status"] = self.status.value
        return payload

    def with_changes(self, **changes: Any) -> Self:
        return replace(self, updated_at=utc_now(), **changes)


@dataclass(frozen=True, slots=True, kw_only=True)
class Project(DmpEntity):
    code: str = "SGODA-PUINAVE"
    repository_url: str = ""


@dataclass(frozen=True, slots=True, kw_only=True)
class ProductVersion(DmpEntity):
    project_id: str
    version: str
    target_date: date | None = None

    def __post_init__(self) -> None:
        super(ProductVersion, self).__post_init__()
        object.__setattr__(self, "project_id", normalize_identifier(self.project_id))
        if not self.version.strip():
            raise ValueError("La versión no puede estar vacía")


@dataclass(frozen=True, slots=True, kw_only=True)
class Sprint(DmpEntity):
    project_id: str
    version_id: str
    starts_on: date | None = None
    ends_on: date | None = None

    def __post_init__(self) -> None:
        super(Sprint, self).__post_init__()
        object.__setattr__(self, "project_id", normalize_identifier(self.project_id))
        object.__setattr__(self, "version_id", normalize_identifier(self.version_id))
        if self.starts_on and self.ends_on and self.ends_on < self.starts_on:
            raise ValueError("La fecha final del sprint no puede preceder la inicial")


@dataclass(frozen=True, slots=True, kw_only=True)
class Spb(DmpEntity):
    sprint_id: str
    version_id: str
    parent_id: str | None = None
    priority: int = 100

    def __post_init__(self) -> None:
        super(Spb, self).__post_init__()
        object.__setattr__(self, "sprint_id", normalize_identifier(self.sprint_id))
        object.__setattr__(self, "version_id", normalize_identifier(self.version_id))
        if self.parent_id:
            object.__setattr__(self, "parent_id", normalize_identifier(self.parent_id))
        if self.priority < 0:
            raise ValueError("La prioridad no puede ser negativa")


@dataclass(frozen=True, slots=True, kw_only=True)
class Requirement(DmpEntity):
    version_id: str
    acceptance_criteria: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        super(Requirement, self).__post_init__()
        object.__setattr__(self, "version_id", normalize_identifier(self.version_id))


@dataclass(frozen=True, slots=True, kw_only=True)
class Deliverable(DmpEntity):
    spb_id: str
    version_id: str
    due_on: date | None = None

    def __post_init__(self) -> None:
        super(Deliverable, self).__post_init__()
        object.__setattr__(self, "spb_id", normalize_identifier(self.spb_id))
        object.__setattr__(self, "version_id", normalize_identifier(self.version_id))


@dataclass(frozen=True, slots=True, kw_only=True)
class SoftwareModule(DmpEntity):
    package: str
    owner: str = ""

    def __post_init__(self) -> None:
        super(SoftwareModule, self).__post_init__()
        if not self.package.strip():
            raise ValueError("El paquete del módulo no puede estar vacío")


@dataclass(frozen=True, slots=True, kw_only=True)
class TestCase(DmpEntity):
    spb_id: str
    test_path: str
    passed: bool | None = None

    def __post_init__(self) -> None:
        super(TestCase, self).__post_init__()
        object.__setattr__(self, "spb_id", normalize_identifier(self.spb_id))
        if not self.test_path.strip():
            raise ValueError("La ruta de prueba no puede estar vacía")


@dataclass(frozen=True, slots=True, kw_only=True)
class Evidence(DmpEntity):
    spb_id: str
    evidence_type: EvidenceType
    reference: str
    checksum: str = ""

    def __post_init__(self) -> None:
        super(Evidence, self).__post_init__()
        object.__setattr__(self, "spb_id", normalize_identifier(self.spb_id))
        if not self.reference.strip():
            raise ValueError("La referencia de evidencia no puede estar vacía")

    def to_dict(self) -> dict[str, Any]:
        payload = super(Evidence, self).to_dict()
        payload["evidence_type"] = self.evidence_type.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Risk(DmpEntity):
    project_id: str
    level: RiskLevel = RiskLevel.MEDIUM
    probability: float = 0.0
    impact: float = 0.0
    mitigation: str = ""

    def __post_init__(self) -> None:
        super(Risk, self).__post_init__()
        object.__setattr__(self, "project_id", normalize_identifier(self.project_id))
        for field_name, value in (("probability", self.probability), ("impact", self.impact)):
            if not 0.0 <= value <= 1.0:
                raise ValueError(f"{field_name} debe estar entre 0 y 1")

    def to_dict(self) -> dict[str, Any]:
        payload = super(Risk, self).to_dict()
        payload["level"] = self.level.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Change(DmpEntity):
    project_id: str
    change_status: ChangeStatus = ChangeStatus.PROPOSED
    requested_by: str = ""
    decision: str = ""

    def __post_init__(self) -> None:
        super(Change, self).__post_init__()
        object.__setattr__(self, "project_id", normalize_identifier(self.project_id))

    def to_dict(self) -> dict[str, Any]:
        payload = super(Change, self).to_dict()
        payload["change_status"] = self.change_status.value
        return payload


@dataclass(frozen=True, slots=True, kw_only=True)
class Milestone(DmpEntity):
    project_id: str
    target_date: date | None = None

    def __post_init__(self) -> None:
        super(Milestone, self).__post_init__()
        object.__setattr__(self, "project_id", normalize_identifier(self.project_id))


DmpRecord = (
    Project
    | ProductVersion
    | Sprint
    | Spb
    | Requirement
    | Deliverable
    | SoftwareModule
    | TestCase
    | Evidence
    | Risk
    | Change
    | Milestone
)
