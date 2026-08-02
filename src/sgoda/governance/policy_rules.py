"""Reglas institucionales verificables de SGD-114C."""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path

from .policy_context import PolicyContext
from .policy_models import (
    PolicyRule,
    RuleResult,
    RuleStatus,
    Severity,
)


RuleExecutor = Callable[[PolicyContext, PolicyRule], RuleResult]


def _passed(
    rule: PolicyRule,
    message: str,
    *evidence: str,
) -> RuleResult:
    return RuleResult(
        rule=rule,
        status=RuleStatus.PASSED,
        message=message,
        evidence=tuple(evidence),
    )


def _failed(
    rule: PolicyRule,
    message: str,
    remediation: str,
    *evidence: str,
    details: dict | None = None,
) -> RuleResult:
    return RuleResult(
        rule=rule,
        status=RuleStatus.FAILED,
        message=message,
        evidence=tuple(evidence),
        remediation=remediation,
        details=details or {},
    )


def repository_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    if (context.root / ".git").is_dir():
        return _passed(rule, "Repositorio Git detectado.", ".git/")

    return _failed(
        rule,
        "No se detectó el repositorio Git.",
        "Ejecute el núcleo desde la raíz del repositorio.",
        ".git/",
    )


def component_descriptor_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    descriptors = context.component_descriptors()

    if descriptors:
        evidence = tuple(
            item.relative_to(context.root).as_posix()
            for item in descriptors
        )
        return _passed(
            rule,
            "Descriptor institucional encontrado.",
            *evidence,
        )

    return _failed(
        rule,
        f"No existe descriptor institucional para {context.increment}.",
        (
            "Cree un descriptor component.json con código, versión, "
            "dependencias, fuentes, pruebas y documentación."
        ),
        "config/",
    )


def release_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    releases = context.releases()

    if releases:
        evidence = tuple(
            item.relative_to(context.root).as_posix()
            for item in releases
        )
        return _passed(
            rule,
            "Release técnico versionado encontrado.",
            *evidence,
        )

    return _failed(
        rule,
        f"No existe release versionado para {context.increment}.",
        "Genere el release técnico antes del cierre.",
        "releases/",
    )


def roadmap_approved(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    validation = context.roadmap_validation()

    if validation is None:
        return _failed(
            rule,
            "No existe validation.json del Roadmap Maestro.",
            "Regenerate SGD-116 antes de solicitar el cierre.",
            "artifacts/roadmap/SGD-116/validation.json",
        )

    counters = {
        "missing_dependencies": len(
            validation.get("missing_dependencies", [])
        ),
        "broken_paths": len(validation.get("broken_paths", [])),
        "dependency_cycles": len(
            validation.get("dependency_cycles", [])
        ),
        "duplicate_codes": len(
            validation.get("duplicate_codes", [])
        ),
        "missing_master_documents": len(
            validation.get("missing_master_documents", [])
        ),
    }

    passed = bool(validation.get("passed")) and all(
        value == 0 for value in counters.values()
    )

    if passed:
        return _passed(
            rule,
            "Roadmap Maestro aprobado y sin errores estructurales.",
            "artifacts/roadmap/SGD-116/validation.json",
        )

    return _failed(
        rule,
        "El Roadmap Maestro contiene incumplimientos.",
        "Corrija los contadores y regenere el Roadmap.",
        "artifacts/roadmap/SGD-116/validation.json",
        details=counters,
    )


def master_documents_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    required = tuple(
        context.policy.get(
            "required_master_documents",
            (
                "docs/00_INDICE_MAESTRO.md",
                "docs/00_ARQUITECTURA_MAESTRA.md",
                "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
                "docs/00_ROADMAP_MAESTRO.md",
                "docs/00_DEPENDENCIAS_MAESTRAS.md",
                "docs/00_TIMELINE_MAESTRO.md",
                "docs/00_METRICAS_ECOSISTEMA.md",
            ),
        )
    )

    missing = [
        path
        for path in required
        if not context.is_file(path)
    ]

    if not missing:
        return _passed(
            rule,
            "Documentos maestros presentes.",
            *required,
        )

    return _failed(
        rule,
        "Faltan documentos maestros obligatorios.",
        "Genere o restaure los documentos mediante SGD-115 y SGD-116.",
        *missing,
        details={"missing": missing},
    )


def tests_evidence_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    candidates = [
        context.root / "tests",
        context.root / "pytest.ini",
    ]

    if all(path.exists() for path in candidates):
        test_count = len(list((context.root / "tests").rglob("test*.py")))

        if test_count > 0:
            return _passed(
                rule,
                f"Infraestructura de pruebas disponible: {test_count} archivos.",
                "tests/",
                "pytest.ini",
            )

    return _failed(
        rule,
        "No se encontró infraestructura suficiente de pruebas.",
        "Restaure pytest.ini y las pruebas institucionales.",
        "tests/",
        "pytest.ini",
    )


def evidence_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    base = context.root / "artifacts" / "pmo" / context.increment

    if not base.is_dir():
        return _failed(
            rule,
            "No existe directorio de evidencias del incremento.",
            "Genere la evidencia técnica y de trazabilidad.",
            f"artifacts/pmo/{context.increment}/",
        )

    files = [item for item in base.rglob("*") if item.is_file()]

    if files:
        return _passed(
            rule,
            f"Evidencias encontradas: {len(files)}.",
            f"artifacts/pmo/{context.increment}/",
        )

    return _failed(
        rule,
        "El directorio de evidencias está vacío.",
        "Genere evidencia legítima antes del cierre.",
        f"artifacts/pmo/{context.increment}/",
    )


def legacy_policy_compatible(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    legacy = (
        context.root
        / "config"
        / "governance"
        / "sgd-114-policy.json"
    )

    if not legacy.is_file():
        return _failed(
            rule,
            "No existe la política heredada SGD-114.",
            "Restaure config/governance/sgd-114-policy.json.",
            "config/governance/sgd-114-policy.json",
        )

    try:
        payload = json.loads(
            legacy.read_text(encoding="utf-8-sig")
        )
    except json.JSONDecodeError as error:
        return _failed(
            rule,
            "La política heredada no contiene JSON válido.",
            "Corrija el archivo sin eliminar su trazabilidad.",
            "config/governance/sgd-114-policy.json",
            details={"error": str(error)},
        )

    if isinstance(payload, dict):
        return _passed(
            rule,
            "Política heredada disponible para compatibilidad.",
            "config/governance/sgd-114-policy.json",
        )

    return _failed(
        rule,
        "La política heredada no es un objeto JSON.",
        "Convierta la política a un objeto JSON válido.",
        "config/governance/sgd-114-policy.json",
    )


BUILTIN_RULES: tuple[tuple[PolicyRule, RuleExecutor], ...] = (
    (
        PolicyRule(
            "SGD114C-R001",
            "Repositorio institucional",
            "Verifica que la ejecución ocurra en un repositorio Git.",
            Severity.BLOCKER,
            "repository",
        ),
        repository_present,
    ),
    (
        PolicyRule(
            "SGD114C-R002",
            "Descriptor del componente",
            "Exige descriptor institucional del incremento.",
            Severity.BLOCKER,
            "traceability",
        ),
        component_descriptor_present,
    ),
    (
        PolicyRule(
            "SGD114C-R003",
            "Release técnico",
            "Exige release técnico versionado.",
            Severity.BLOCKER,
            "release",
        ),
        release_present,
    ),
    (
        PolicyRule(
            "SGD114C-R004",
            "Roadmap Maestro",
            "Exige Roadmap aprobado y sin errores.",
            Severity.BLOCKER,
            "roadmap",
        ),
        roadmap_approved,
    ),
    (
        PolicyRule(
            "SGD114C-R005",
            "Documentación maestra",
            "Exige documentos maestros del ecosistema.",
            Severity.BLOCKER,
            "documentation",
        ),
        master_documents_present,
    ),
    (
        PolicyRule(
            "SGD114C-R006",
            "Infraestructura de pruebas",
            "Verifica que exista evidencia ejecutable de pruebas.",
            Severity.BLOCKER,
            "quality",
        ),
        tests_evidence_present,
    ),
    (
        PolicyRule(
            "SGD114C-R007",
            "Evidencia institucional",
            "Exige evidencia del incremento.",
            Severity.BLOCKER,
            "evidence",
        ),
        evidence_present,
    ),
    (
        PolicyRule(
            "SGD114C-R008",
            "Compatibilidad SGD-114",
            "Mantiene disponible la política heredada.",
            Severity.BLOCKER,
            "compatibility",
        ),
        legacy_policy_compatible,
    ),
)