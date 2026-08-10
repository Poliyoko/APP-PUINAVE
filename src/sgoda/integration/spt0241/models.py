from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class SecurityAsset:
    asset_id: str
    path: str
    asset_type: str
    criticality: str
    data_classification: str
    exposed_surface: bool
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "asset_id": self.asset_id,
            "path": self.path,
            "asset_type": self.asset_type,
            "criticality": self.criticality,
            "data_classification": self.data_classification,
            "exposed_surface": self.exposed_surface,
            "metadata": dict(self.metadata),
        }


@dataclass(frozen=True)
class SecurityFinding:
    code: str
    severity: str
    asset_id: str
    message: str
    evidence: dict[str, Any] = field(default_factory=dict)

    @property
    def blocking(self) -> bool:
        return self.severity.upper() in {"ERROR", "CRITICAL"}

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "severity": self.severity,
            "asset_id": self.asset_id,
            "message": self.message,
            "evidence": dict(self.evidence),
            "blocking": self.blocking,
        }


@dataclass
class SecurityBaseline:
    assets: list[SecurityAsset] = field(default_factory=list)
    findings: list[SecurityFinding] = field(default_factory=list)

    @property
    def blocking_findings(self) -> list[SecurityFinding]:
        return [item for item in self.findings if item.blocking]

    @property
    def conformant(self) -> bool:
        return not self.blocking_findings

    def to_dict(self) -> dict[str, Any]:
        return {
            "assets": [item.to_dict() for item in self.assets],
            "findings": [item.to_dict() for item in self.findings],
            "asset_count": len(self.assets),
            "finding_count": len(self.findings),
            "blocking_count": len(self.blocking_findings),
            "conformant": self.conformant,
        }
