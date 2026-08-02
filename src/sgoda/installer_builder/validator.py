from __future__ import annotations

import re
from pathlib import Path

CODE_PATTERN = re.compile(
    r"^(?:SPB|SPT|SGD|ADR|SIB)-\d{3}(?:\.\d+|[A-Z])?$"
)


class SpecificationError(ValueError):
    pass


def validate_code(code: str) -> str:
    value = code.strip().upper()
    if not CODE_PATTERN.fullmatch(value):
        raise SpecificationError(
            "CÃ³digo no vÃ¡lido. Ejemplos: SPT-004C, SGD-116, "
            "ADR-012 o SIB-002."
        )
    return value


def validate_name(name: str) -> str:
    value = " ".join(name.split())
    if len(value) < 5:
        raise SpecificationError(
            "El nombre debe contener al menos 5 caracteres."
        )
    return value


def validate_generated_package(root: str | Path) -> list[str]:
    package = Path(root)
    required = {
        "installer.ps1",
        "repair-template.ps1",
        "component.json",
        "policy.json",
        "README.md",
        "test_increment.py",
        "manifest.json",
        "PUBLICATION-COMMANDS.ps1",
    }
    existing = (
        {item.name for item in package.iterdir() if item.is_file()}
        if package.is_dir()
        else set()
    )
    errors = [
        f"Archivo obligatorio faltante: {name}"
        for name in sorted(required - existing)
    ]
    for path in package.glob("*"):
        if path.is_file() and path.stat().st_size == 0:
            errors.append(f"Archivo vacÃ­o: {path.name}")
    return errors