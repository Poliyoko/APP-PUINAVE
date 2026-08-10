from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class SecretAssessment:
    path: str
    line: int
    detector: str
    fingerprint: str
    classification: str
    severity: str
    requires_rotation: bool
    requires_removal_from_git: bool
    rationale: str

    @property
    def blocking(self) -> bool:
        return self.severity.upper() in {"ERROR", "CRITICAL"}

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "line": self.line,
            "detector": self.detector,
            "fingerprint": self.fingerprint,
            "classification": self.classification,
            "severity": self.severity,
            "requires_rotation": self.requires_rotation,
            "requires_removal_from_git": self.requires_removal_from_git,
            "rationale": self.rationale,
            "blocking": self.blocking,
        }


@dataclass(frozen=True)
class CredentialControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "control_id": self.control_id,
            "name": self.name,
            "passed": self.passed,
            "blocking": self.blocking,
            "detail": self.detail,
        }


@dataclass(frozen=True)
class SecurityGateResult:
    passed: bool
    failed_blocking_controls: tuple[str, ...]
    controls: tuple[CredentialControl, ...]
    assessed_candidates: int
    real_risk_candidates: int
    false_positive_candidates: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "passed": self.passed,
            "failed_blocking_controls": list(self.failed_blocking_controls),
            "controls": [item.to_dict() for item in self.controls],
            "assessed_candidates": self.assessed_candidates,
            "real_risk_candidates": self.real_risk_candidates,
            "false_positive_candidates": self.false_positive_candidates,
        }
