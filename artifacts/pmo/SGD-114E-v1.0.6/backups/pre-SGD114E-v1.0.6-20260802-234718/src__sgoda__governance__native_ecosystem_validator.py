"""Validador de arquitectura nativa SGD-114E v1.0.5."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .native_ecosystem_models import (
    NativeEcosystemValidationResult,
)


_FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract-based integration",
    "contract integration",
)


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


def _contains_forbidden_term(
    path: Path,
) -> tuple[dict[str, str], ...]:
    try:
        text = path.read_text(
            encoding="utf-8-sig",
            errors="replace",
        ).casefold()
    except OSError:
        return ()

    findings = []

    for term in _FORBIDDEN_TERMS:
        if term in text:
            findings.append(
                {
                    "path": path.as_posix(),
                    "term": term,
                }
            )

    return tuple(findings)


def evaluate_native_ecosystem(
    root: str | Path,
) -> NativeEcosystemValidationResult:
    project_root = Path(root).resolve()
    component_files = _component_files(project_root)

    native_components = []
    proprietary_dependencies = []
    structural_errors = []

    for path in component_files:
        payload = _read_json(path)

        if payload is None:
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": "invalid_or_unreadable_json",
                }
            )
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("component")
            or path.stem
        )

        native_flag = payload.get("native_ecosystem")

        if native_flag is True:
            native_components.append(code)

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
            continue

        for dependency in dependencies:
            text = str(dependency).strip()

            if text:
                proprietary_dependencies.append(
                    {
                        "component": code,
                        "dependency": text,
                        "path": path.as_posix(),
                    }
                )

    forbidden_terms = []

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

            forbidden_terms.extend(
                _contains_forbidden_term(path)
            )

    criteria = {
        "has_native_components": len(native_components) > 0,
        "no_forbidden_terms": len(forbidden_terms) == 0,
        "no_mandatory_proprietary_dependencies": (
            len(proprietary_dependencies) == 0
        ),
        "no_structural_errors": len(structural_errors) == 0,
    }

    approved = all(criteria.values())

    return NativeEcosystemValidationResult(
        {
            "policy": "SGD-114E",
            "version": "1.0.5",
            "approved": approved,
            "result": (
                "APROBADO"
                if approved
                else "NO APROBADO"
            ),
            "criteria": criteria,
            "native_component_count": len(native_components),
            "native_components": sorted(
                set(native_components)
            ),
            "forbidden_term_count": len(forbidden_terms),
            "forbidden_terms": forbidden_terms,
            "mandatory_proprietary_dependency_count": (
                len(proprietary_dependencies)
            ),
            "mandatory_proprietary_dependencies": (
                proprietary_dependencies
            ),
            "structural_error_count": len(structural_errors),
            "structural_errors": structural_errors,
            "decision_rule": (
                "approved = has_native_components AND "
                "no_forbidden_terms AND "
                "no_mandatory_proprietary_dependencies AND "
                "no_structural_errors"
            ),
            "compatibility": {
                "attribute_access": True,
                "mapping_access": True,
                "to_dict": True,
            },
        }
    )