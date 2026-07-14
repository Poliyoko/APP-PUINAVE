"""Modelos del motor de auditoría SGODA."""

from dataclasses import dataclass
from enum import StrEnum


class Severity(StrEnum):
    """Nivel de severidad de un hallazgo."""

    SUCCESS = "success"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"


@dataclass(frozen=True, slots=True)
class AuditFinding:
    """Hallazgo producido por una regla de auditoría."""

    rule_id: str
    severity: Severity
    message: str
    path: str | None = None
    recommendation: str | None = None
    category: str = "general"

    def to_dict(self) -> dict[str, str | None]:
        """Convierte el hallazgo a una estructura serializable."""
        return {
            "rule_id": self.rule_id,
            "severity": self.severity.value,
            "category": self.category,
            "message": self.message,
            "path": self.path,
            "recommendation": self.recommendation,
        }
