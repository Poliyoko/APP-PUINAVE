"""Descubrimiento automático de componentes y activos."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .models import ComponentRecord


COMPONENT_PATTERN = re.compile(
    r"^(ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+(?:\.[0-9]+)?[A-Z]?$"
)

VERSIONED_CODE_PATTERN = re.compile(
    r"^((?:ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+"
    r"(?:\.[0-9]+)?[A-Z]?)(?:-v[0-9].*)?$",
    re.IGNORECASE,
)


def canonical_component_code(value: str) -> str:
    """Normaliza códigos con sufijos de versión al código institucional."""
    clean = value.strip().split()[0].rstrip(",;")
    match = VERSIONED_CODE_PATTERN.match(clean)
    if match:
        return match.group(1).upper()
    return clean


def _list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item).replace("\\", "/") for item in value]
    if isinstance(value, str) and value.strip():
        return [value.replace("\\", "/")]
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


def _component_from_payload(
    repository: Path,
    path: Path,
    payload: dict[str, Any],
) -> ComponentRecord | None:
    raw_code = str(
        payload.get("increment_code")
        or payload.get("code")
        or payload.get("component_code")
        or ""
    ).strip()

    code = canonical_component_code(raw_code)
    if not code or not COMPONENT_PATTERN.match(code):
        return None

    name = str(
        payload.get("name")
        or payload.get("component_name")
        or code
    ).strip()

    component_type = str(
        payload.get("component_type")
        or payload.get("type")
        or "unspecified"
    ).strip()

    dependencies = [
        canonical_component_code(item)
        for item in _list(
            payload.get("dependencies")
            or payload.get("depends_on")
            or payload.get("governed_by")
        )
    ]

    release_matches = sorted(
        (repository / "releases").glob(f"{code}-v*")
    )
    release_path = (
        release_matches[-1].relative_to(repository).as_posix()
        if release_matches
        else None
    )

    return ComponentRecord(
        code=code,
        name=name,
        version=str(payload.get("version", "0.0.0")),
        status=str(payload.get("status", "registered")),
        component_type=component_type,
        phase=str(
            payload.get("phase")
            or infer_phase(code, component_type)
        ),
        dependencies=dependencies,
        source_paths=_list(
            payload.get("source")
            or payload.get("source_paths")
        ),
        test_paths=_list(
            payload.get("tests")
            or payload.get("test_paths")
        ),
        documentation_paths=_list(
            payload.get("documentation")
            or payload.get("documents")
        ),
        release_path=release_path,
        config_path=path.relative_to(repository).as_posix(),
        metadata={
            "raw_status": payload.get("status"),
            "raw_code": raw_code,
            "canonical_code": code,
        },
    )


def _discover_canonical_governance_anchors(
    repository: Path,
    existing_codes: set[str],
) -> list[ComponentRecord]:
    """Reconoce componentes históricos con descriptores no canónicos."""
    anchors: list[ComponentRecord] = []

    definitions = (
        {
            "code": "SGD-114",
            "name": "Política Institucional de Repositorio, Evidencias y Trazabilidad",
            "version": "2.0.1",
            "status": "technically_completed",
            "component_type": "repository_governance",
            "evidence_candidates": (
                "artifacts/pmo/SGD-114-v2/SGD-114-v2-quality-gate.json",
                "artifacts/pmo/SGD-114/SGD-114-quality-gate.json",
                "src/sgoda/governance/repository_governance.py",
            ),
            "source": (
                "src/sgoda/governance/repository_governance.py",
            ),
            "tests": (
                "tests/governance/test_SGD_114_v2_repository_governance.py",
                "tests/governance/test_sgd_114_evidence_policy.py",
            ),
            "documents": (
                "docs/01_Gobierno/SGD-114-v2.0-Politica-Repositorio-Institucional.md",
            ),
        },
    )

    for definition in definitions:
        code = str(definition["code"])
        if code in existing_codes:
            continue

        if not any(
            (repository / candidate).exists()
            for candidate in definition["evidence_candidates"]
        ):
            continue

        source_paths = [
            value
            for value in definition["source"]
            if (repository / value).exists()
        ]
        test_paths = [
            value
            for value in definition["tests"]
            if (repository / value).exists()
        ]
        document_paths = [
            value
            for value in definition["documents"]
            if (repository / value).exists()
        ]

        release_matches = sorted(
            (repository / "releases").glob(f"{code}-v*")
        )

        anchors.append(
            ComponentRecord(
                code=code,
                name=str(definition["name"]),
                version=str(definition["version"]),
                status=str(definition["status"]),
                component_type=str(definition["component_type"]),
                phase=infer_phase(
                    code,
                    str(definition["component_type"]),
                ),
                dependencies=[],
                source_paths=source_paths,
                test_paths=test_paths,
                documentation_paths=document_paths,
                release_path=(
                    release_matches[-1]
                    .relative_to(repository)
                    .as_posix()
                    if release_matches
                    else None
                ),
                config_path=None,
                metadata={
                    "synthetic_canonical_anchor": True,
                    "discovery_reason": (
                        "Historical implementation evidence found."
                    ),
                },
            )
        )

    return anchors


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    for path in sorted(repository.glob("config/**/*component*.json")):
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(payload, dict):
            continue

        record = _component_from_payload(
            repository,
            path,
            payload,
        )
        if record is not None:
            records.append(record)

    existing_codes = {item.code for item in records}
    records.extend(
        _discover_canonical_governance_anchors(
            repository,
            existing_codes,
        )
    )

    deduplicated: dict[str, ComponentRecord] = {}
    for record in records:
        previous = deduplicated.get(record.code)
        if previous is None:
            deduplicated[record.code] = record
            continue
        if record.version >= previous.version:
            deduplicated[record.code] = record

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