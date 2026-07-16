"""Compatibilidad SemVer para Builder y dependencias de plugins."""

from __future__ import annotations

import re

VERSION_PATTERN = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
COMPARATOR_PATTERN = re.compile(
    r"^(>=|>|==|=|<=|<)?\s*(\d+\.\d+\.\d+)$"
)


class CompatibilityError(ValueError):
    """Expresión de compatibilidad inválida."""


def parse_version(value: str) -> tuple[int, int, int]:
    match = VERSION_PATTERN.fullmatch(value.strip())
    if not match:
        raise CompatibilityError(f"Versión SemVer inválida: {value}")
    return tuple(int(match.group(index)) for index in (1, 2, 3))


def _satisfies_comparator(
    version: tuple[int, int, int],
    comparator: str,
) -> bool:
    match = COMPARATOR_PATTERN.fullmatch(comparator.strip())
    if not match:
        raise CompatibilityError(
            f"Comparador de versión inválido: {comparator}"
        )
    operator = match.group(1) or "=="
    required = tuple(int(part) for part in match.group(2).split("."))
    return {
        ">=": version >= required,
        ">": version > required,
        "==": version == required,
        "=": version == required,
        "<=": version <= required,
        "<": version < required,
    }[operator]


def requirement_satisfied(requirement: str, current: str) -> bool:
    """Evalúa requisitos como ``>=1.6.0,<2.0.0``."""
    comparators = [
        item.strip()
        for item in requirement.split(",")
        if item.strip()
    ]
    if not comparators:
        raise CompatibilityError("El requisito de versión está vacío.")
    version = parse_version(current.split("-", 1)[0])
    return all(
        _satisfies_comparator(version, comparator)
        for comparator in comparators
    )
