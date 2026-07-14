"""Informes del motor de auditoría SGODA."""

import json
from dataclasses import dataclass
from pathlib import Path

from .models import AuditFinding, Severity


@dataclass(frozen=True, slots=True)
class AuditReport:
    """Resultado consolidado de una auditoría."""

    workspace: Path
    findings: tuple[AuditFinding, ...]

    @property
    def errors(self) -> int:
        return sum(item.severity is Severity.ERROR for item in self.findings)

    @property
    def warnings(self) -> int:
        return sum(item.severity is Severity.WARNING for item in self.findings)

    @property
    def information(self) -> int:
        return sum(item.severity is Severity.INFO for item in self.findings)

    @property
    def successes(self) -> int:
        return sum(item.severity is Severity.SUCCESS for item in self.findings)

    @property
    def passed(self) -> bool:
        return self.errors == 0

    @property
    def status(self) -> str:
        return "OK" if self.passed else "ERROR"

    def to_dict(self) -> dict[str, object]:
        """Convierte el informe a una estructura serializable."""
        return {
            "workspace": str(self.workspace),
            "status": self.status,
            "summary": {
                "errors": self.errors,
                "warnings": self.warnings,
                "information": self.information,
                "successes": self.successes,
            },
            "findings": [item.to_dict() for item in self.findings],
        }

    def to_json(self) -> str:
        """Serializa el informe en JSON."""
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)

    def to_text(self) -> str:
        """Presenta el informe para consola."""
        lines = [
            "Auditoría SGODA",
            f"Proyecto: {self.workspace}",
            "-" * 60,
        ]

        if not self.findings:
            lines.append("[OK] No se encontraron hallazgos.")

        markers = {
            Severity.SUCCESS: "OK",
            Severity.INFO: "INFO",
            Severity.WARNING: "ADVERTENCIA",
            Severity.ERROR: "ERROR",
        }

        for item in self.findings:
            marker = markers[item.severity]
            location = f" ({item.path})" if item.path else ""
            lines.append(
                f"[{marker}] {item.rule_id} [{item.category}]: "
                f"{item.message}{location}"
            )
            if item.recommendation:
                lines.append(f"  Recomendación: {item.recommendation}")

        lines.extend(
            [
                "-" * 60,
                f"Errores: {self.errors}",
                f"Advertencias: {self.warnings}",
                f"Información: {self.information}",
                f"Controles aprobados: {self.successes}",
                f"Estado: {self.status}",
            ]
        )
        return "\n".join(lines)
