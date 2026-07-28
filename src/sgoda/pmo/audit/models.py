from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any


class Severity(str, Enum):
    INFO = "INFO"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class Status(str, Enum):
    PASS = "PASS"
    WARN = "WARN"
    FAIL = "FAIL"
    SKIP = "SKIP"


@dataclass(frozen=True)
class Finding:
    code: str
    category: str
    title: str
    severity: Severity
    status: Status
    evidence: str = ""
    recommendation: str = ""
    blocking: bool | None = None

    def is_blocking(self) -> bool:
        if self.blocking is not None:
            return self.blocking
        return self.status == Status.FAIL and self.severity in {
            Severity.HIGH,
            Severity.CRITICAL,
        }

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["severity"] = self.severity.value
        data["status"] = self.status.value
        data["blocking"] = self.is_blocking()
        return data


@dataclass
class AuditResult:
    repository: str = ""
    project: str = "SGODA-PUINAVE"
    scope: str = "SPB-003.2 - Auditoría modular de cierre"
    generated_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    branch: str = ""
    commit: str = ""
    findings: list[Finding] = field(default_factory=list)
    inventory: dict[str, Any] = field(default_factory=dict)
    verdict: str = "PENDING"
    compliance_percentage: float = 0.0

    def finalize(self):
        evaluated = [f for f in self.findings if f.status != Status.SKIP]
        passed = sum(f.status == Status.PASS for f in evaluated)
        self.compliance_percentage = (
            round(100 * passed / len(evaluated), 2) if evaluated else 0.0
        )
        blocking = any(f.is_blocking() for f in evaluated)
        failures = any(f.status == Status.FAIL for f in evaluated)
        warnings = any(f.status == Status.WARN for f in evaluated)
        self.verdict = (
            "NOT_APPROVED"
            if blocking
            else ("APPROVED_WITH_ACTIONS" if failures or warnings else "APPROVED")
        )
        return self

    def to_dict(self):
        return {
            "project": self.project,
            "scope": self.scope,
            "generated_at": self.generated_at,
            "repository": self.repository,
            "branch": self.branch,
            "commit": self.commit,
            "verdict": self.verdict,
            "compliance_percentage": self.compliance_percentage,
            "blocking_findings": sum(f.is_blocking() for f in self.findings),
            "inventory": self.inventory,
            "findings": [f.to_dict() for f in self.findings],
        }
