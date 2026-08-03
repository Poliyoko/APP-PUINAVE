"""SGD-114E v2.0.0-R2 — validador nativo sin falsos positivos."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Iterable

from .native_ecosystem_models import (
    NativeEcosystemFinding,
    NativeEcosystemValidationResult,
)


_MAPPING_CONTRACT_VERSION = "1.0.3"
_ATTRIBUTE_CONTRACT_VERSION = "1.0.5"
_IMPLEMENTATION_VERSION = "2.0.0"

_FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract-based integration",
    "contract integration",
)

_SPT_PATTERN = re.compile(r"^SPT-(\d+)")

_TEXT_SUFFIXES = {
    ".json",
    ".md",
    ".txt",
    ".yaml",
    ".yml",
}

_EXCLUDED_DIRECTORY_NAMES = {
    ".git",
    ".venv",
    "__pycache__",
    "artifacts",
    "releases",
    "backups",
    "legacy-tests",
    "node_modules",
}

_EXCLUDED_FILE_NAME_PARTS = {
    "sgd-114e",
    "native-ecosystem",
    "terminologia-institucional",
    "terminología-institucional",
}


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(
            path.read_text(encoding="utf-8-sig")
        )
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None

    return payload if isinstance(payload, dict) else None


def _is_excluded_path(path: Path) -> bool:
    lowered_parts = {
        part.casefold()
        for part in path.parts
    }

    if lowered_parts & _EXCLUDED_DIRECTORY_NAMES:
        return True

    lowered_name = path.name.casefold()

    return any(
        marker in lowered_name
        for marker in _EXCLUDED_FILE_NAME_PARTS
    )


def _component_files(root: Path) -> tuple[Path, ...]:
    config = root / "config"

    if not config.exists():
        return ()

    return tuple(
        sorted(
            path
            for path in config.rglob("*.json")
            if not _is_excluded_path(path)
            and (
                "component" in path.name.casefold()
                or "metadata" in path.name.casefold()
            )
        )
    )


def _component_code(
    payload: dict[str, Any],
    path: Path,
) -> str:
    return str(
        payload.get("increment_code")
        or payload.get("component")
        or path.stem
    )


def _is_governed_component(code: str) -> bool:
    normalized = str(code or "").strip().upper()
    match = _SPT_PATTERN.match(normalized)

    if match:
        return int(match.group(1)) >= 7

    return normalized.startswith(
        (
            "SGD-",
            "SPB-",
            "SPA-",
        )
    )


def _active_text_files(
    project_root: Path,
) -> Iterable[Path]:
    """Entrega únicamente documentación/configuración institucional activa."""

    for base in (
        project_root / "config",
        project_root / "docs",
    ):
        if not base.exists():
            continue

        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue

            if path.suffix.casefold() not in _TEXT_SUFFIXES:
                continue

            if _is_excluded_path(path):
                continue

            yield path


def _scan_forbidden_terms(
    project_root: Path,
) -> tuple[NativeEcosystemFinding, ...]:
    findings = []

    for path in _active_text_files(project_root):
        try:
            text = path.read_text(
                encoding="utf-8-sig",
                errors="replace",
            ).casefold()
        except OSError:
            continue

        for term in _FORBIDDEN_TERMS:
            if term in text:
                findings.append(
                    NativeEcosystemFinding(
                        rule_code="SGD114E-R003",
                        message=(
                            "Se detectó terminología institucional "
                            "prohibida en contenido activo."
                        ),
                        path=path.as_posix(),
                        value=term,
                    )
                )

    return tuple(findings)


def evaluate_native_ecosystem(
    root: str | Path,
) -> NativeEcosystemValidationResult:
    project_root = Path(root).resolve()

    governed_count = 0
    native_components = []
    proprietary_dependencies = []
    structural_errors = []
    findings = []

    for path in _component_files(project_root):
        payload = _read_json(path)

        if payload is None:
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": "invalid_or_unreadable_json",
                }
            )
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R004",
                    message="JSON de componente inválido.",
                    path=path.as_posix(),
                )
            )
            continue

        code = _component_code(payload, path)

        if not _is_governed_component(code):
            continue

        governed_count += 1

        if payload.get("native_ecosystem") is True:
            native_components.append(code)
        else:
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R002",
                    message=(
                        "El componente gobernado debe declararse "
                        "como nativo."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )

        dependencies = payload.get(
            "mandatory_proprietary_dependencies",
            [],
        )

        if dependencies is None:
            dependencies = []

        if not isinstance(dependencies, list):
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": (
                        "mandatory_proprietary_dependencies "
                        "must be a list"
                    ),
                }
            )
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R004",
                    message=(
                        "mandatory_proprietary_dependencies "
                        "debe ser una lista."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )
            continue

        for dependency in dependencies:
            value = str(dependency).strip()

            if value:
                proprietary_dependencies.append(
                    {
                        "component": code,
                        "dependency": value,
                        "path": path.as_posix(),
                    }
                )
                findings.append(
                    NativeEcosystemFinding(
                        rule_code="SGD114E-R001",
                        message=(
                            "Se detectó una dependencia "
                            "propietaria obligatoria."
                        ),
                        path=path.as_posix(),
                        component=code,
                        value=value,
                    )
                )

    forbidden_findings = list(
        _scan_forbidden_terms(project_root)
    )
    findings.extend(forbidden_findings)

    repository_is_empty = governed_count == 0
    has_native_components = len(native_components) > 0
    approved = len(findings) == 0

    criteria = {
        "has_native_components": has_native_components,
        "all_governed_components_are_native": not any(
            item.rule_code == "SGD114E-R002"
            for item in findings
        ),
        "no_forbidden_terms": len(forbidden_findings) == 0,
        "no_mandatory_proprietary_dependencies": (
            len(proprietary_dependencies) == 0
        ),
        "no_structural_errors": len(structural_errors) == 0,
        "empty_repository_allowed": True,
    }

    return NativeEcosystemValidationResult(
        {
            "policy": "SGD-114E",
            "version": _MAPPING_CONTRACT_VERSION,
            "attribute_version": (
                _ATTRIBUTE_CONTRACT_VERSION
            ),
            "implementation_version": (
                _IMPLEMENTATION_VERSION
            ),
            "revision": "R2.1",
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "result": (
                "APROBADO"
                if approved
                else "NO APROBADO"
            ),
            "repository_is_empty": repository_is_empty,
            "governed_component_count": governed_count,
            "criteria": criteria,
            "native_component_count": len(
                native_components
            ),
            "component_count": len(native_components),
            "native_components": sorted(
                set(native_components)
            ),
            "forbidden_term_count": len(
                forbidden_findings
            ),
            "forbidden_terms": [
                finding.to_dict()
                for finding in forbidden_findings
            ],
            "mandatory_proprietary_dependency_count": (
                len(proprietary_dependencies)
            ),
            "proprietary_dependency_count": (
                len(proprietary_dependencies)
            ),
            "mandatory_proprietary_dependencies": (
                proprietary_dependencies
            ),
            "structural_error_count": len(
                structural_errors
            ),
            "structural_errors": structural_errors,
            "findings": findings,
            "scan_scope": {
                "included": [
                    "config active files",
                    "docs active files",
                ],
                "excluded": sorted(
                    _EXCLUDED_DIRECTORY_NAMES
                ),
                "policy_files_excluded": True,
                "source_code_excluded": True,
            },
            "decision_rule": (
                "approved = no institutional findings"
            ),
        }
    )