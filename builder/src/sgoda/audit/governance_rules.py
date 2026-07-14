"""Reglas DAMA-DMBOK, FAIR y CARE."""

import json
from pathlib import Path
from typing import Any

from .models import AuditFinding, Severity


REQUIRED_FRAMEWORKS = {"DAMA-DMBOK", "FAIR", "CARE"}
CARE_FIELDS = (
    "collective_benefit",
    "authority_to_control",
    "responsibility",
    "ethics",
)


def rule_governance(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida responsables y estructura de gobierno."""
    if manifest is None:
        return []

    governance = manifest.get("governance")
    if not isinstance(governance, dict):
        return [
            AuditFinding(
                "SGODA-GOV-001",
                Severity.ERROR,
                "Falta el objeto governance.",
                "sgoda.project.json",
                "Declare propiedad, custodia y marcos de gobierno.",
                "governance",
            )
        ]

    findings: list[AuditFinding] = []

    owner = governance.get("data_owner")
    if not isinstance(owner, str) or not owner.strip():
        findings.append(
            AuditFinding(
                "SGODA-GOV-002",
                Severity.ERROR,
                "No se ha definido el propietario de los datos.",
                "governance.data_owner",
                "Declare a la comunidad o autoridad propietaria.",
                "governance",
            )
        )
    else:
        findings.append(
            AuditFinding(
                "SGODA-GOV-OK-001",
                Severity.SUCCESS,
                "Propietario de datos definido.",
                "governance.data_owner",
                category="governance",
            )
        )

    steward = governance.get("data_steward")
    if not isinstance(steward, str) or not steward.strip():
        findings.append(
            AuditFinding(
                "SGODA-GOV-003",
                Severity.WARNING,
                "No se ha definido un custodio o data steward.",
                "governance.data_steward",
                "Declare el responsable operativo de la calidad de datos.",
                "governance",
            )
        )

    frameworks = governance.get("frameworks")
    if not isinstance(frameworks, list):
        findings.append(
            AuditFinding(
                "SGODA-GOV-004",
                Severity.ERROR,
                "governance.frameworks debe ser una lista.",
                "governance.frameworks",
                category="governance",
            )
        )
    else:
        normalized = {str(item).upper() for item in frameworks}
        missing = {
            framework
            for framework in REQUIRED_FRAMEWORKS
            if framework.upper() not in normalized
        }
        if missing:
            findings.append(
                AuditFinding(
                    "SGODA-GOV-005",
                    Severity.WARNING,
                    "Faltan marcos de gobierno obligatorios: "
                    + ", ".join(sorted(missing)),
                    "governance.frameworks",
                    "Incluya DAMA-DMBOK, FAIR y CARE.",
                    "governance",
                )
            )
        else:
            findings.append(
                AuditFinding(
                    "SGODA-GOV-OK-002",
                    Severity.SUCCESS,
                    "Marcos DAMA-DMBOK, FAIR y CARE declarados.",
                    "governance.frameworks",
                    category="governance",
                )
            )

    classification = governance.get("classification")
    if not isinstance(classification, str) or not classification.strip():
        findings.append(
            AuditFinding(
                "SGODA-GOV-006",
                Severity.WARNING,
                "No existe clasificación de los datos.",
                "governance.classification",
                "Declare la clasificación cultural y de sensibilidad.",
                "governance",
            )
        )

    return findings


def rule_care(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida principios CARE para datos comunitarios."""
    if manifest is None:
        return []

    governance = manifest.get("governance")
    if not isinstance(governance, dict):
        return []

    care = governance.get("care")
    if not isinstance(care, dict):
        return [
            AuditFinding(
                "SGODA-CARE-001",
                Severity.WARNING,
                "No se documentan los principios CARE.",
                "governance.care",
                "Declare beneficio colectivo, autoridad, responsabilidad y ética.",
                "care",
            )
        ]

    missing = [field for field in CARE_FIELDS if care.get(field) is not True]
    if missing:
        return [
            AuditFinding(
                "SGODA-CARE-002",
                Severity.WARNING,
                "Principios CARE incompletos: " + ", ".join(missing),
                "governance.care",
                "Revise los cuatro principios CARE con la comunidad.",
                "care",
            )
        ]

    return [
        AuditFinding(
            "SGODA-CARE-OK-001",
            Severity.SUCCESS,
            "Los cuatro principios CARE están declarados.",
            "governance.care",
            category="care",
        )
    ]


def rule_fair(
    workspace: Path,
    manifest: dict[str, Any] | None,
) -> list[AuditFinding]:
    """Valida catálogo y atributos FAIR mínimos."""
    catalog_path = workspace / "data/metadata/catalog.json"

    if not catalog_path.is_file():
        return [
            AuditFinding(
                "SGODA-FAIR-002",
                Severity.ERROR,
                "No existe el catálogo de metadatos FAIR.",
                "data/metadata/catalog.json",
                "Genere o restaure el catálogo de metadatos.",
                "fair",
            )
        ]

    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [
            AuditFinding(
                "SGODA-FAIR-003",
                Severity.ERROR,
                f"El catálogo de metadatos no es JSON válido: {exc}",
                "data/metadata/catalog.json",
                category="fair",
            )
        ]

    required = ("title", "description", "owner", "license", "datasets")
    missing = [
        field
        for field in required
        if field not in catalog or catalog[field] in (None, "", [])
    ]

    if missing:
        return [
            AuditFinding(
                "SGODA-FAIR-004",
                Severity.WARNING,
                "Metadatos FAIR incompletos: " + ", ".join(missing),
                "data/metadata/catalog.json",
                "Complete identificabilidad, acceso y reutilización.",
                "fair",
            )
        ]

    return [
        AuditFinding(
            "SGODA-FAIR-OK-001",
            Severity.SUCCESS,
            "Catálogo FAIR mínimo completo.",
            "data/metadata/catalog.json",
            category="fair",
        )
    ]
