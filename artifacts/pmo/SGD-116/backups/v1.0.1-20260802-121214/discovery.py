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


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    for path in sorted(repository.glob("config/**/*component*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("code")
            or payload.get("component_code")
            or ""
        ).strip()

        if not code or not COMPONENT_PATTERN.match(code):
            continue

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

        dependencies = _list(
            payload.get("dependencies")
            or payload.get("depends_on")
            or payload.get("governed_by")
        )

        release_candidate = repository / "releases"
        release_matches = sorted(
            release_candidate.glob(f"{code}-v*")
        )
        release_path = (
            release_matches[-1].relative_to(repository).as_posix()
            if release_matches
            else None
        )

        records.append(
            ComponentRecord(
                code=code,
                name=name,
                version=str(payload.get("version", "0.0.0")),
                status=str(
                    payload.get("status", "registered")
                ),
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
                config_path=path.relative_to(
                    repository
                ).as_posix(),
                metadata={
                    "raw_status": payload.get("status"),
                },
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