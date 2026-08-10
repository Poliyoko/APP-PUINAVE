from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class DatabaseSurface:
    path: str
    surface_type: str
    runtime_relevant: bool
    secret_indirection: bool
    tls_declared: bool
    superuser_marker: bool
    unsafe_sql_marker: bool
    rationale: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "surface_type": self.surface_type,
            "runtime_relevant": self.runtime_relevant,
            "secret_indirection": self.secret_indirection,
            "tls_declared": self.tls_declared,
            "superuser_marker": self.superuser_marker,
            "unsafe_sql_marker": self.unsafe_sql_marker,
            "rationale": self.rationale,
        }


@dataclass(frozen=True)
class DataSecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "control_id": self.control_id,
            "name": self.name,
            "passed": self.passed,
            "blocking": self.blocking,
            "detail": self.detail,
        }


@dataclass
class DataSecurityReport:
    controls: list[DataSecurityControl] = field(default_factory=list)
    surfaces: list[DatabaseSurface] = field(default_factory=list)

    @property
    def failed_blocking_controls(self) -> list[DataSecurityControl]:
        return [c for c in self.controls if c.blocking and not c.passed]

    @property
    def conformant(self) -> bool:
        return not self.failed_blocking_controls

    def to_dict(self) -> dict[str, Any]:
        return {
            "controls": [c.to_dict() for c in self.controls],
            "surfaces": [s.to_dict() for s in self.surfaces],
            "failed_blocking_controls": [
                c.control_id for c in self.failed_blocking_controls
            ],
            "conformant": self.conformant,
        }
