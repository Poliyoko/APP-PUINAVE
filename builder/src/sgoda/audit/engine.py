"""Motor base de auditoría y calidad SGODA."""

from pathlib import Path

from .models import AuditFinding, Severity
from .report import AuditReport
from .rules import BASE_RULES, AuditRule, load_manifest


class AuditEngine:
    """Ejecuta reglas sobre un proyecto SGODA."""

    def __init__(
        self,
        rules: tuple[AuditRule, ...] = BASE_RULES,
    ) -> None:
        self.rules = rules

    def audit(self, workspace: str | Path) -> AuditReport:
        """Audita el proyecto indicado."""
        resolved_workspace = Path(workspace).expanduser().resolve()
        findings: list[AuditFinding] = []

        if not resolved_workspace.is_dir():
            findings.append(
                AuditFinding(
                    "SGODA-WORKSPACE-001",
                    severity=Severity.ERROR,
                    message="El directorio del proyecto no existe.",
                    path=str(resolved_workspace),
                )
            )
            return AuditReport(resolved_workspace, tuple(findings))

        manifest, manifest_findings = load_manifest(resolved_workspace)
        findings.extend(manifest_findings)

        for rule in self.rules:
            findings.extend(rule(resolved_workspace, manifest))

        return AuditReport(resolved_workspace, tuple(findings))
