from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class WorkflowSurface:
    path: str
    surface_type: str
    active_runtime: bool
    secret_reference_only: bool
    webhook_exposure: bool
    unsafe_command_execution: bool
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "surface_type": self.surface_type,
            "active_runtime": self.active_runtime,
            "secret_reference_only": self.secret_reference_only,
            "webhook_exposure": self.webhook_exposure,
            "unsafe_command_execution": self.unsafe_command_execution,
            "metadata": dict(self.metadata),
        }


@dataclass(frozen=True)
class AutomationSecurityControl:
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
class AutomationSecurityReport:
    controls: list[AutomationSecurityControl] = field(default_factory=list)
    surfaces: list[WorkflowSurface] = field(default_factory=list)

    @property
    def failed_blocking_controls(self) -> list[AutomationSecurityControl]:
        return [
            item for item in self.controls
            if item.blocking and not item.passed
        ]

    @property
    def conformant(self) -> bool:
        return not self.failed_blocking_controls

    def to_dict(self) -> dict[str, Any]:
        return {
            "controls": [item.to_dict() for item in self.controls],
            "surfaces": [item.to_dict() for item in self.surfaces],
            "failed_blocking_controls": [
                item.control_id
                for item in self.failed_blocking_controls
            ],
            "conformant": self.conformant,
        }
