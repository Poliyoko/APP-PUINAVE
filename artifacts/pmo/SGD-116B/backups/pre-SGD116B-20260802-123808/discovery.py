"""Descubrimiento institucional y resolución canónica."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .models import ComponentRecord


CANONICAL_PATTERN = re.compile(
    r"^(ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+(?:\.[0-9]+)?[A-Z]?$",
    re.IGNORECASE,
)

VERSION_SUFFIX_PATTERN = re.compile(
    r"^(?P<code>(?:ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+"
    r"(?:\.[0-9]+)?[A-Z]?)"
    r"(?:-v[0-9]+(?:\.[0-9]+)*(?:[-._A-Za-z0-9]*)?)?$",
    re.IGNORECASE,
)


def canonical_component_code(value: str) -> str:
    """Convierte una referencia versionada en su código institucional."""
    clean = str(value).strip()
    if not clean:
        return ""

    clean = clean.split()[0].rstrip(",;:")
    match = VERSION_SUFFIX_PATTERN.match(clean)
    if match:
        return match.group("code").upper()

    return clean.upper()


def _as_paths(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value.replace("\\", "/")] if value.strip() else []
    if isinstance(value, list):
        return [
            str(item).replace("\\", "/")
            for item in value
            if str(item).strip()
        ]
    return []


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


def repository_evidence(
    root: str | Path,
    code: str,
) -> list[str]:
    """Busca evidencia real asociada a un código canónico."""
    repository = Path(root)
    normalized = canonical_component_code(code)
    if not normalized:
        return []

    needle = normalized.lower()
    matches: set[str] = set()

    roots = (
        "config",
        "src",
        "tests",
        "docs",
        "scripts",
        "artifacts/pmo",
        "releases",
        "dashboard",
    )

    for base in roots:
        location = repository / base
        if not location.exists():
            continue

        for path in location.rglob("*"):
            try:
                relative = path.relative_to(repository).as_posix()
            except ValueError:
                continue

            if needle in path.name.lower():
                matches.add(relative)
                continue

            if path.is_file() and path.suffix.lower() in {
                ".json",
                ".md",
                ".py",
                ".ps1",
                ".txt",
            }:
                try:
                    content = path.read_text(
                        encoding="utf-8-sig",
                        errors="ignore",
                    )
                except OSError:
                    continue

                if normalized in content:
                    matches.add(relative)

            if len(matches) >= 25:
                break

    return sorted(matches)


def _record_from_descriptor(
    repository: Path,
    path: Path,
    payload: dict[str, Any],
) -> ComponentRecord | None:
    raw_code = str(
        payload.get("increment_code")
        or payload.get("component_code")
        or payload.get("code")
        or ""
    ).strip()

    code = canonical_component_code(raw_code)
    if not CANONICAL_PATTERN.match(code):
        return None

    component_type = str(
        payload.get("component_type")
        or payload.get("type")
        or "unspecified"
    ).strip()

    dependencies = [
        canonical_component_code(item)
        for item in _as_paths(
            payload.get("dependencies")
            or payload.get("depends_on")
            or payload.get("governed_by")
        )
        if canonical_component_code(item)
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
        source_paths=_as_paths(
            payload.get("source")
            or payload.get("source_paths")
        ),
        test_paths=_as_paths(
            payload.get("tests")
            or payload.get("test_paths")
        ),
        documentation_paths=_as_paths(
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
            "raw_code": raw_code,
            "canonical_code": code,
            "descriptor": path.relative_to(
                repository
            ).as_posix(),
        },
    )


def _anchor_from_evidence(
    repository: Path,
    code: str,
    evidence: list[str],
) -> ComponentRecord:
    source_paths = [
        item
        for item in evidence
        if item.startswith("src/") and item.endswith(".py")
    ]
    test_paths = [
        item
        for item in evidence
        if item.startswith("tests/") and item.endswith(".py")
    ]
    documentation_paths = [
        item
        for item in evidence
        if item.startswith("docs/")
    ]
    releases = [
        item
        for item in evidence
        if item.startswith("releases/")
    ]

    return ComponentRecord(
        code=code,
        name=f"Componente histórico {code}",
        version="historical",
        status="historically_implemented",
        component_type="historical_component_anchor",
        phase=infer_phase(code, "historical_component_anchor"),
        dependencies=[],
        source_paths=source_paths[:10],
        test_paths=test_paths[:10],
        documentation_paths=documentation_paths[:10],
        release_path=releases[-1] if releases else None,
        config_path=None,
        metadata={
            "synthetic_canonical_anchor": True,
            "evidence_count": len(evidence),
            "evidence": evidence[:25],
        },
    )


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    descriptor_patterns = (
        "config/**/*component*.json",
        "config/**/*Component*.json",
    )

    descriptor_paths: set[Path] = set()
    for pattern in descriptor_patterns:
        descriptor_paths.update(repository.glob(pattern))

    for path in sorted(descriptor_paths):
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(payload, dict):
            continue

        record = _record_from_descriptor(
            repository,
            path,
            payload,
        )
        if record:
            records.append(record)

    deduplicated: dict[str, ComponentRecord] = {}
    for record in records:
        current = deduplicated.get(record.code)
        if current is None:
            deduplicated[record.code] = record
            continue

        current_has_config = current.config_path is not None
        record_has_config = record.config_path is not None

        if record_has_config and not current_has_config:
            deduplicated[record.code] = record
        elif record.version >= current.version:
            deduplicated[record.code] = record

    dependency_targets = {
        canonical_component_code(dependency)
        for record in deduplicated.values()
        for dependency in record.dependencies
        if canonical_component_code(dependency)
    }

    for target in sorted(dependency_targets):
        if target in deduplicated:
            continue

        evidence = repository_evidence(repository, target)
        if evidence:
            deduplicated[target] = _anchor_from_evidence(
                repository,
                target,
                evidence,
            )

    return sorted(
        deduplicated.values(),
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