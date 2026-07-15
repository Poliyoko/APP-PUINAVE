"""Modelos de observabilidad del SGODA Project Builder."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Literal

HealthStatus = Literal["HEALTHY", "WARNING", "ERROR"]


@dataclass(frozen=True, slots=True)
class ProjectSnapshot:
    name: str
    version: str
    type: str
    status: str
    schema_version: str
    created_at: str | None = None
    updated_at: str | None = None


@dataclass(frozen=True, slots=True)
class AuditSnapshot:
    status: str
    score: int
    errors: int
    warnings: int
    information: int
    successes: int
    categories: dict[str, dict[str, int]] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LifecycleSnapshot:
    migrations: int
    last_migrated_at: str | None = None
    last_repaired_at: str | None = None
    managed_by: str | None = None


@dataclass(frozen=True, slots=True)
class ExtensionSnapshot:
    plugins: int
    templates: int
    enabled: int


@dataclass(frozen=True, slots=True)
class ResourceSnapshot:
    lexicon: bool
    metadata_catalog: bool
    governance_documentation: bool

    @property
    def available(self) -> int:
        return sum((self.lexicon, self.metadata_catalog, self.governance_documentation))

    @property
    def total(self) -> int:
        return 3


@dataclass(frozen=True, slots=True)
class OperationStatus:
    workspace: str
    builder_version: str
    collected_at: str
    project: ProjectSnapshot
    audit: AuditSnapshot
    lifecycle: LifecycleSnapshot
    extensions: ExtensionSnapshot
    resources: ResourceSnapshot
    components: dict[str, int]
    health: HealthStatus

    def to_dict(self, *, detailed: bool = True) -> dict[str, Any]:
        payload = asdict(self)
        if not detailed:
            payload = {
                "workspace": self.workspace,
                "builder": {"version": self.builder_version},
                "project": {
                    "name": self.project.name,
                    "version": self.project.version,
                    "schema_version": self.project.schema_version,
                },
                "quality": {
                    "score": self.audit.score,
                    "errors": self.audit.errors,
                    "warnings": self.audit.warnings,
                    "status": self.audit.status,
                },
                "extensions": {
                    "plugins": self.extensions.plugins,
                    "templates": self.extensions.templates,
                },
                "health": self.health,
                "collected_at": self.collected_at,
            }
        return payload
