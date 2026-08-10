from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class AuditFinding:
    dimension: str
    code: str
    severity: str
    message: str
    subject: str = ""
    evidence: dict[str, Any] = field(default_factory=dict)

    @property
    def blocking(self) -> bool:
        return self.severity.upper() in {"ERROR", "CRITICAL"}


@dataclass
class AuditReport:
    scope: tuple[str, ...]
    findings: list[AuditFinding] = field(default_factory=list)
    metrics: dict[str, Any] = field(default_factory=dict)

    @property
    def blocking_findings(self) -> list[AuditFinding]:
        return [item for item in self.findings if item.blocking]

    @property
    def conformant(self) -> bool:
        return not self.blocking_findings

    def count_by_dimension(self) -> dict[str, int]:
        result: dict[str, int] = {}
        for finding in self.findings:
            result[finding.dimension] = result.get(finding.dimension, 0) + 1
        return result

    def to_dict(self) -> dict[str, Any]:
        return {
            "scope": list(self.scope),
            "conformant": self.conformant,
            "blocking_count": len(self.blocking_findings),
            "metrics": dict(self.metrics),
            "findings": [
                {
                    "dimension": f.dimension,
                    "code": f.code,
                    "severity": f.severity,
                    "message": f.message,
                    "subject": f.subject,
                    "evidence": dict(f.evidence),
                }
                for f in self.findings
            ],
        }
