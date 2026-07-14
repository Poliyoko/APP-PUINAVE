"""Reglas de dependencias entre componentes SGODA."""

from pathlib import Path
from typing import Any

from .models import AuditFinding, Severity


def rule_component_dependencies(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida dependencias lógicas entre componentes registrados."""
    if manifest is None:
        return []

    components = manifest.get("components", {})
    if not isinstance(components, dict):
        return []

    findings: list[AuditFinding] = []
    keys = set(components)

    api_components = [
        key for key in keys if key.startswith("api:")
    ]
    if api_components and "backend" not in keys:
        findings.append(
            AuditFinding(
                "SGODA-DEPENDENCY-001",
                Severity.WARNING,
                "Existen APIs registradas sin un backend registrado.",
                "sgoda.project.json",
                "Genere o registre el componente backend.",
                "dependencies",
            )
        )

    workflow_components = [
        key for key in keys if key.startswith("workflow:")
    ]
    if workflow_components and not (workspace / "automation/n8n").is_dir():
        findings.append(
            AuditFinding(
                "SGODA-DEPENDENCY-002",
                Severity.ERROR,
                "Existen workflows registrados sin directorio n8n.",
                "automation/n8n",
                "Restaure la estructura de automatización.",
                "dependencies",
            )
        )

    modules = [
        key for key in keys if key.startswith("module:")
    ]
    if modules and not (workspace / "modules").is_dir():
        findings.append(
            AuditFinding(
                "SGODA-DEPENDENCY-003",
                Severity.ERROR,
                "Existen módulos registrados sin directorio modules.",
                "modules",
                "Restaure la estructura modular.",
                "dependencies",
            )
        )

    if not findings:
        findings.append(
            AuditFinding(
                "SGODA-DEPENDENCY-OK-001",
                Severity.SUCCESS,
                "Dependencias básicas entre componentes consistentes.",
                "sgoda.project.json",
                category="dependencies",
            )
        )

    return findings
