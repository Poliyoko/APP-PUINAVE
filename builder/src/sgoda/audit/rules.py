"""Reglas base de auditoría para proyectos SGODA."""

import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

from sgoda.core.constants import DEFAULT_DIRECTORIES, REQUIRED_PROJECT_FILES

from .models import AuditFinding, Severity
from .dependency_rules import rule_component_dependencies
from .governance_rules import rule_care, rule_fair, rule_governance
from .quality_rules import (
    rule_governance_documentation,
    rule_lexicon_quality,
    rule_metadata,
)

AuditRule = Callable[[Path, dict[str, Any] | None], list[AuditFinding]]

SUPPORTED_SCHEMA_VERSIONS = {"1.0", "1.1", "1.2", "1.3"}

COMPONENT_PATHS: dict[str, tuple[str, ...]] = {
    "backend": ("backend",),
    "frontend": ("frontend/web",),
    "database": ("database",),
    "module": ("modules/{name}",),
    "api": ("backend/src/app/api/{name}",),
    "workflow": ("automation/n8n/{name}.json",),
    "docs": ("docs/08_Desarrollo/{name}.md",),
}


def load_manifest(
    workspace: Path,
) -> tuple[dict[str, Any] | None, list[AuditFinding]]:
    """Carga y valida sintácticamente el manifiesto."""
    path = workspace / "sgoda.project.json"

    if not path.is_file():
        return None, [
            AuditFinding(
                "SGODA-MANIFEST-001",
                Severity.ERROR,
                "No existe el manifiesto sgoda.project.json.",
                str(path),
                "Ejecute 'sgoda init' o restaure el manifiesto.",
            )
        ]

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, [
            AuditFinding(
                "SGODA-MANIFEST-002",
                Severity.ERROR,
                f"El manifiesto no es un JSON válido: {exc}",
                str(path),
                "Corrija el JSON antes de continuar.",
            )
        ]

    if not isinstance(data, dict):
        return None, [
            AuditFinding(
                "SGODA-MANIFEST-003",
                Severity.ERROR,
                "La raíz del manifiesto debe ser un objeto JSON.",
                str(path),
            )
        ]

    return data, []


def rule_project_identity(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida la identidad mínima del proyecto."""
    if manifest is None:
        return []

    project = manifest.get("project")
    if not isinstance(project, dict):
        return [
            AuditFinding(
                "SGODA-PROJECT-001",
                Severity.ERROR,
                "Falta el objeto 'project' en el manifiesto.",
                "sgoda.project.json",
            )
        ]

    findings: list[AuditFinding] = []

    if project.get("type") != "SGODA":
        findings.append(
            AuditFinding(
                "SGODA-PROJECT-002",
                Severity.ERROR,
                "El tipo del proyecto debe ser 'SGODA'.",
                "sgoda.project.json",
            )
        )

    name = project.get("name")
    if not isinstance(name, str) or not name.strip():
        findings.append(
            AuditFinding(
                "SGODA-PROJECT-003",
                Severity.ERROR,
                "El proyecto debe tener un nombre no vacío.",
                "sgoda.project.json",
            )
        )

    return findings


def rule_schema_version(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida la versión del esquema del manifiesto."""
    if manifest is None:
        return []

    version = manifest.get("schema_version")

    if version is None:
        return [
            AuditFinding(
                "SGODA-SCHEMA-001",
                Severity.WARNING,
                "El manifiesto no declara schema_version.",
                "sgoda.project.json",
                "Declare una versión compatible, por ejemplo '1.1'.",
            )
        ]

    if str(version) not in SUPPORTED_SCHEMA_VERSIONS:
        return [
            AuditFinding(
                "SGODA-SCHEMA-002",
                Severity.WARNING,
                f"Versión de esquema no reconocida: {version}.",
                "sgoda.project.json",
                "Revise la compatibilidad con el Builder instalado.",
            )
        ]

    return []


def rule_required_structure(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida carpetas y archivos obligatorios."""
    findings: list[AuditFinding] = []

    for relative_path in DEFAULT_DIRECTORIES:
        path = workspace / relative_path
        if not path.is_dir():
            findings.append(
                AuditFinding(
                    "SGODA-STRUCTURE-001",
                    Severity.ERROR,
                    "Falta un directorio obligatorio.",
                    relative_path,
                    "Ejecute nuevamente 'sgoda init' sin eliminar contenido.",
                )
            )

    for relative_path in REQUIRED_PROJECT_FILES:
        path = workspace / relative_path
        if not path.is_file():
            findings.append(
                AuditFinding(
                    "SGODA-STRUCTURE-002",
                    Severity.ERROR,
                    "Falta un archivo obligatorio.",
                    relative_path,
                    "Restaure o regenere el archivo requerido.",
                )
            )

    return findings


def rule_registered_components(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Comprueba que los componentes registrados existan físicamente."""
    if manifest is None:
        return []

    components = manifest.get("components", {})

    if not isinstance(components, dict):
        return [
            AuditFinding(
                "SGODA-COMPONENT-001",
                Severity.ERROR,
                "'components' debe ser un objeto JSON.",
                "sgoda.project.json",
            )
        ]

    findings: list[AuditFinding] = []

    if not components:
        findings.append(
            AuditFinding(
                "SGODA-COMPONENT-002",
                Severity.INFO,
                "El proyecto aún no registra componentes generados.",
                "sgoda.project.json",
            )
        )
        return findings

    for key, value in components.items():
        if not isinstance(value, dict):
            findings.append(
                AuditFinding(
                    "SGODA-COMPONENT-003",
                    Severity.ERROR,
                    f"El registro '{key}' debe ser un objeto.",
                    "sgoda.project.json",
                )
            )
            continue

        component_type = value.get("type")
        name = value.get("name")
        patterns = COMPONENT_PATHS.get(str(component_type))

        if patterns is None:
            findings.append(
                AuditFinding(
                    "SGODA-COMPONENT-004",
                    Severity.WARNING,
                    f"Tipo de componente no reconocido: {component_type}.",
                    f"components.{key}",
                )
            )
            continue

        for pattern in patterns:
            if "{name}" in pattern and not name:
                findings.append(
                    AuditFinding(
                        "SGODA-COMPONENT-005",
                        Severity.ERROR,
                        f"El componente '{key}' requiere nombre.",
                        f"components.{key}",
                    )
                )
                continue

            relative_path = pattern.format(name=name)
            path = workspace / relative_path

            if not path.exists():
                findings.append(
                    AuditFinding(
                        "SGODA-COMPONENT-006",
                        Severity.ERROR,
                        f"El componente registrado '{key}' no existe físicamente.",
                        relative_path,
                        "Regénere el componente o corrija el manifiesto.",
                    )
                )

    return findings


BASE_RULES: tuple[AuditRule, ...] = (
    rule_project_identity,
    rule_schema_version,
    rule_required_structure,
    rule_registered_components,
    rule_governance,
    rule_fair,
    rule_care,
    rule_metadata,
    rule_lexicon_quality,
    rule_governance_documentation,
    rule_component_dependencies,
)
