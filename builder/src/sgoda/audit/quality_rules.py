"""Reglas de calidad de datos y documentación."""

import json
from pathlib import Path
from typing import Any

from .models import AuditFinding, Severity


def rule_metadata(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida metadatos esenciales del proyecto."""
    if manifest is None:
        return []

    findings: list[AuditFinding] = []
    project = manifest.get("project", {})

    if not isinstance(project, dict):
        return findings

    version = project.get("version")
    if not isinstance(version, str) or not version.strip():
        findings.append(
            AuditFinding(
                "SGODA-META-001",
                Severity.WARNING,
                "El proyecto no declara una versión.",
                "project.version",
                "Declare una versión semántica inicial.",
                "metadata",
            )
        )

    created_at = project.get("created_at")
    if not isinstance(created_at, str) or not created_at.strip():
        findings.append(
            AuditFinding(
                "SGODA-META-002",
                Severity.INFO,
                "El proyecto no declara fecha de creación.",
                "project.created_at",
                category="metadata",
            )
        )

    if not findings:
        findings.append(
            AuditFinding(
                "SGODA-META-OK-001",
                Severity.SUCCESS,
                "Metadatos esenciales del proyecto completos.",
                "sgoda.project.json",
                category="metadata",
            )
        )

    return findings


def rule_lexicon_quality(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida la estructura mínima del conjunto léxico."""
    path = workspace / "data/json/palabras.json"

    if not path.is_file():
        return []

    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [
            AuditFinding(
                "SGODA-QUALITY-001",
                Severity.ERROR,
                f"El archivo léxico no es JSON válido: {exc}",
                "data/json/palabras.json",
                category="data-quality",
            )
        ]

    records = payload.get("records")
    if not isinstance(records, list):
        return [
            AuditFinding(
                "SGODA-QUALITY-002",
                Severity.ERROR,
                "'records' debe ser una lista.",
                "data/json/palabras.json",
                category="data-quality",
            )
        ]

    if not records:
        return [
            AuditFinding(
                "SGODA-QUALITY-003",
                Severity.INFO,
                "El conjunto léxico todavía no contiene registros.",
                "data/json/palabras.json",
                "Incorpore registros validados por la comunidad.",
                "data-quality",
            )
        ]

    required_fields = {"term_puinave", "meaning_es"}
    incomplete = sum(
        1
        for record in records
        if not isinstance(record, dict)
        or not required_fields.issubset(record)
    )

    if incomplete:
        return [
            AuditFinding(
                "SGODA-QUALITY-004",
                Severity.WARNING,
                f"Registros léxicos incompletos: {incomplete}.",
                "data/json/palabras.json",
                "Complete término Puinave y significado en español.",
                "data-quality",
            )
        ]

    return [
        AuditFinding(
            "SGODA-QUALITY-OK-001",
            Severity.SUCCESS,
            "Estructura del conjunto léxico válida.",
            "data/json/palabras.json",
            category="data-quality",
        )
    ]


def rule_governance_documentation(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida documentación mínima de gobierno."""
    path = workspace / "docs/00_Gobierno/README.md"

    if not path.is_file():
        return [
            AuditFinding(
                "SGODA-DOC-001",
                Severity.ERROR,
                "Falta la documentación de gobierno.",
                "docs/00_Gobierno/README.md",
                "Documente propiedad, custodia y autoridad comunitaria.",
                "documentation",
            )
        ]

    content = path.read_text(encoding="utf-8").strip()
    if len(content) < 80:
        return [
            AuditFinding(
                "SGODA-DOC-002",
                Severity.WARNING,
                "La documentación de gobierno es insuficiente.",
                "docs/00_Gobierno/README.md",
                "Amplíe propiedad, custodia, marcos y responsabilidades.",
                "documentation",
            )
        ]

    return [
        AuditFinding(
            "SGODA-DOC-OK-001",
            Severity.SUCCESS,
            "Documentación de gobierno disponible.",
            "docs/00_Gobierno/README.md",
            category="documentation",
        )
    ]
