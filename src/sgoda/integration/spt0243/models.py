from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class ServiceExposure:
    path: str
    method: str
    source: str
    sensitive: bool
    native_auth: bool
    gateway_auth: bool

    @property
    def authenticated(self) -> bool | None:
        if not self.sensitive:
            return None
        return self.native_auth or self.gateway_auth

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "method": self.method,
            "source": self.source,
            "sensitive": self.sensitive,
            "native_auth": self.native_auth,
            "gateway_auth": self.gateway_auth,
            "authenticated": self.authenticated,
        }


@dataclass(frozen=True)
class ApiSecurityControl:
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
class ApiSecurityReport:
    controls: list[ApiSecurityControl] = field(default_factory=list)
    exposures: list[ServiceExposure] = field(default_factory=list)

    @property
    def failed_blocking_controls(self) -> list[ApiSecurityControl]:
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
            "exposures": [item.to_dict() for item in self.exposures],
            "failed_blocking_controls": [
                item.control_id for item in self.failed_blocking_controls
            ],
            "conformant": self.conformant,
        }
