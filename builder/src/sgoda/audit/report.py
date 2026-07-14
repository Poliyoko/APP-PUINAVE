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

    @property
    def score(self) -> int:
        """Calcula una puntuación simple de calidad entre 0 y 100."""
        penalty = (self.errors * 25) + (self.warnings * 8)
        return max(0, 100 - penalty)

    def exit_code(self, *, strict: bool = False) -> int:
        """Devuelve el código de salida para automatización."""
        if self.errors:
            return 1
        if strict and self.warnings:
            return 2
        return 0

    def to_dict(self) -> dict[str, object]:
        """Convierte el informe a una estructura serializable."""
        return {
            "workspace": str(self.workspace),
            "status": self.status,
            "score": self.score,
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

    def to_markdown(self) -> str:
        """Genera un informe Markdown persistible."""
        lines = [
            "# Informe de Auditoría SGODA",
            "",
            f"- **Proyecto:** `{self.workspace}`",
            f"- **Estado:** **{self.status}**",
            f"- **Puntuación:** **{self.score}/100**",
            "",
            "## Resumen",
            "",
            "| Métrica | Total |",
            "|---|---:|",
            f"| Errores | {self.errors} |",
            f"| Advertencias | {self.warnings} |",
            f"| Información | {self.information} |",
            f"| Controles aprobados | {self.successes} |",
            "",
            "## Hallazgos",
            "",
        ]

        if not self.findings:
            lines.append("No se encontraron hallazgos.")
            return "\n".join(lines) + "\n"

        lines.extend(
            [
                "| Severidad | Regla | Categoría | Mensaje | Ruta |",
                "|---|---|---|---|---|",
            ]
        )

        for item in self.findings:
            message = item.message.replace("|", r"\|")
            path = (item.path or "").replace("|", r"\|")
            lines.append(
                f"| {item.severity.value} | {item.rule_id} | "
                f"{item.category} | {message} | {path} |"
            )

        lines.append("")

        recommendations = [
            item
            for item in self.findings
            if item.recommendation
        ]
        if recommendations:
            lines.extend(["## Recomendaciones", ""])
            for item in recommendations:
                lines.append(
                    f"- **{item.rule_id}:** {item.recommendation}"
                )
            lines.append("")

        return "\n".join(lines)

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
                f"Puntuación: {self.score}/100",
                f"Estado: {self.status}",
            ]
        )
        return "\n".join(lines)
