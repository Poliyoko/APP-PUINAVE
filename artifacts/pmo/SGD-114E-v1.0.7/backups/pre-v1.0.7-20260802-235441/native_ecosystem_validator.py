"""Validador definitivo SGD-114E v1.0.6."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .native_ecosystem_models import (
    NativeEcosystemFinding,
    NativeEcosystemValidationResult,
)


_CONTRACT_VERSION = "1.0.3"
_IMPLEMENTATION_VERSION = "1.0.6"

_FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract-based integration",
    "contract integration",
)

_SPT_PATTERN = re.compile(r"^SPT-(\d+)")


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(
            path.read_text(encoding="utf-8-sig")
        )
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None

    return payload if isinstance(payload, dict) else None


def _component_files(root: Path) -> tuple[Path, ...]:
    config = root / "config"

    if not config.exists():
        return ()

    return tuple(
        sorted(
            path
            for path in config.rglob("*.json")
            if (
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


def _scan_forbidden_terms(
    project_root: Path,
) -> tuple[NativeEcosystemFinding, ...]:
    findings = []

    for base in (
        project_root / "config",
        project_root / "docs",
        project_root / "src",
    ):
        if not base.exists():
            continue

        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue

            if path.suffix.casefold() not in {
                ".json",
                ".md",
                ".py",
                ".ps1",
                ".txt",
                ".yaml",
                ".yml",
            }:
                continue

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
                                "Se detectó terminología "
                                "institucional prohibida."
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

        if "native_ecosystem" not in payload:
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R002",
                    message=(
                        "El componente gobernado no declara "
                        "native_ecosystem."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )
        elif payload.get("native_ecosystem") is True:
            native_components.append(code)
        elif payload.get("native_ecosystem") is False:
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R002",
                    message=(
                        "El componente gobernado no está "
                        "declarado como nativo."
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
            text = str(dependency).strip()

            if text:
                item = {
                    "component": code,
                    "dependency": text,
                    "path": path.as_posix(),
                }
                proprietary_dependencies.append(item)
                findings.append(
                    NativeEcosystemFinding(
                        rule_code="SGD114E-R001",
                        message=(
                            "Se detectó una dependencia "
                            "propietaria obligatoria."
                        ),
                        path=path.as_posix(),
                        component=code,
                        value=text,
                    )
                )

    forbidden_findings = list(
        _scan_forbidden_terms(project_root)
    )
    findings.extend(forbidden_findings)

    approved = len(findings) == 0

    criteria = {
        "all_governed_components_are_native": not any(
            item.rule_code == "SGD114E-R002"
            for item in findings
        ),
        "no_forbidden_terms": not any(
            item.rule_code == "SGD114E-R003"
            for item in findings
        ),
        "no_mandatory_proprietary_dependencies": (
            len(proprietary_dependencies) == 0
        ),
        "no_structural_errors": len(structural_errors) == 0,
    }

    return NativeEcosystemValidationResult(
        {
            "policy": "SGD-114E",
            "version": _CONTRACT_VERSION,
            "implementation_version": (
                _IMPLEMENTATION_VERSION
            ),
            "approved": approved,
            "result": (
                "APROBADO"
                if approved
                else "NO APROBADO"
            ),
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
                item.to_dict()
                for item in forbidden_findings
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
            "decision_rule": (
                "approved = no institutional findings"
            ),
            "compatibility": {
                "historical_attributes": True,
                "mapping_access": True,
                "to_dict": True,
                "contract_version": _CONTRACT_VERSION,
                "implementation_version": (
                    _IMPLEMENTATION_VERSION
                ),
            },
        }
    )