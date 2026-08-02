"""Descubrimiento híbrido institucional de SGD-116B."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .aliases import (
    canonical_component_code,
    is_supported_component_code,
    resolve_alias,
)
from .models import ComponentRecord


def _paths(value: Any) -> list[str]:
    if isinstance(value, str):
        value = [value]

    if not isinstance(value, list):
        return []

    return [
        str(item).replace("\\", "/")
        for item in value
        if str(item).strip()
    ]


def infer_phase(code: str, component_type: str) -> str:
    if code.startswith(("SGD-", "ADR-")):
        return "Gobierno y arquitectura"
    if code.startswith(("SPB-", "SIB-", "MMGR-")):
        return "Plataforma y construcción"
    if code.startswith("SPT-001"):
        return "Repositorio Léxico Base"
    if code.startswith("SPT-002"):
        return "Objetos Digitales de Aprendizaje"
    if code.startswith("SPT-003"):
        return "Automatización multimedia"
    if code.startswith("SPT-004"):
        return "Asistente e integraciones"
    if code.startswith("SPT-005"):
        return "Identidad cultural"
    if code.startswith("SPT-006"):
        return "Motor multilingüe y multimedia"
    return component_type or "Evolución futura"


def _descriptor_record(
    repository: Path,
    path: Path,
    payload: dict[str, Any],
) -> ComponentRecord | None:
    raw_code = (
        payload.get("increment_code")
        or payload.get("component_code")
        or payload.get("code")
        or ""
    )

    resolution = resolve_alias(raw_code)

    if not resolution.valid_format:
        return None

    code = resolution.canonical
    component_type = str(
        payload.get("component_type")
        or payload.get("type")
        or "unspecified"
    ).strip()

    dependencies: list[str] = []
    raw_dependencies = (
        payload.get("dependencies")
        or payload.get("depends_on")
        or payload.get("governed_by")
        or []
    )

    if isinstance(raw_dependencies, str):
        raw_dependencies = [raw_dependencies]

    if isinstance(raw_dependencies, list):
        dependencies = [
            str(item)
            for item in raw_dependencies
            if str(item).strip()
        ]

    release_matches = sorted(
        (repository / "releases").glob(f"{code}-v*")
    )

    return ComponentRecord(
        code=code,
        name=str(
            payload.get("name")
            or payload.get("component_name")
            or code
        ).strip(),
        version=str(payload.get("version", "0.0.0")),
        status=str(payload.get("status", "registered")),
        component_type=component_type,
        phase=str(
            payload.get("phase")
            or infer_phase(code, component_type)
        ),
        dependencies=dependencies,
        source_paths=_paths(
            payload.get("source")
            or payload.get("source_paths")
        ),
        test_paths=_paths(
            payload.get("tests")
            or payload.get("test_paths")
        ),
        documentation_paths=_paths(
            payload.get("documentation")
            or payload.get("documents")
        ),
        release_path=(
            release_matches[-1]
            .relative_to(repository)
            .as_posix()
            if release_matches
            else None
        ),
        config_path=path.relative_to(repository).as_posix(),
        metadata={
            "discovery_source": "descriptor",
            "raw_code": str(raw_code),
            "canonical_code": code,
            "alias_applied": resolution.changed,
        },
    )


def institutional_evidence(
    root: str | Path,
    code: str,
) -> list[str]:
    repository = Path(root)
    canonical = canonical_component_code(code)

    if not canonical or not is_supported_component_code(canonical):
        return []

    normalized = canonical.lower()
    evidence: set[str] = set()

    locations = (
        "src",
        "tests",
        "docs",
        "config",
        "scripts",
        "releases",
        "artifacts/pmo",
        "dashboard",
    )

    for location in locations:
        base = repository / location
        if not base.exists():
            continue

        for path in base.rglob("*"):
            if len(evidence) >= 50:
                break

            try:
                relative = path.relative_to(repository).as_posix()
            except ValueError:
                continue

            if normalized in path.name.lower():
                evidence.add(relative)

    return sorted(evidence)


def _historical_record(
    repository: Path,
    code: str,
    evidence: list[str],
) -> ComponentRecord:
    source_paths = [
        item for item in evidence
        if item.startswith("src/") and item.endswith(".py")
    ]
    test_paths = [
        item for item in evidence
        if item.startswith("tests/") and item.endswith(".py")
    ]
    documentation_paths = [
        item for item in evidence
        if item.startswith("docs/")
    ]
    release_paths = [
        item for item in evidence
        if item.startswith("releases/")
    ]

    return ComponentRecord(
        code=code,
        name=f"Componente institucional histórico {code}",
        version="historical",
        status="historically_implemented",
        component_type="historical_component",
        phase=infer_phase(code, "historical_component"),
        dependencies=[],
        source_paths=source_paths,
        test_paths=test_paths,
        documentation_paths=documentation_paths,
        release_path=release_paths[-1] if release_paths else None,
        config_path=None,
        metadata={
            "discovery_source": "institutional_evidence",
            "synthetic_canonical_anchor": True,
            "evidence_count": len(evidence),
            "evidence": evidence,
        },
    )


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    descriptor_paths = sorted(
        set(
            repository.glob("config/**/*component*.json")
        )
        | set(
            repository.glob("config/**/*Component*.json")
        )
    )

    for path in descriptor_paths:
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(payload, dict):
            continue

        record = _descriptor_record(
            repository,
            path,
            payload,
        )
        if record:
            records.append(record)

    by_code: dict[str, ComponentRecord] = {}

    for record in records:
        current = by_code.get(record.code)

        if current is None:
            by_code[record.code] = record
            continue

        current_descriptor = current.config_path is not None
        new_descriptor = record.config_path is not None

        if new_descriptor and not current_descriptor:
            by_code[record.code] = record
        elif record.version >= current.version:
            by_code[record.code] = record

    dependency_codes = {
        canonical_component_code(dependency)
        for component in by_code.values()
        for dependency in component.dependencies
        if is_supported_component_code(dependency)
    }

    for dependency_code in sorted(dependency_codes):
        if dependency_code in by_code:
            continue

        evidence = institutional_evidence(
            repository,
            dependency_code,
        )

        if evidence:
            by_code[dependency_code] = _historical_record(
                repository,
                dependency_code,
                evidence,
            )

    return sorted(
        by_code.values(),
        key=lambda item: item.code,
    )


def discover_repository_assets(root: str | Path) -> dict:
    repository = Path(root)

    return {
        "test_files": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("tests/**/*.py")
            if path.name.startswith("test")
        ),
        "documents": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("docs/**/*")
            if path.is_file()
        ),
        "releases": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("releases/*")
            if path.is_dir()
        ),
        "scripts": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("scripts/*.ps1")
        ),
        "source_files": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("src/**/*.py")
        ),
    }