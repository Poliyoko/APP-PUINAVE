"""Política nativa del ecosistema SGODA-PUINAVE."""

from __future__ import annotations

import re
from typing import Any


_NATIVE_SPT = re.compile(
    r"^SPT-(?P<number>\d+)(?P<suffix>[A-Z]?)$",
    re.IGNORECASE,
)


FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract integration",
    "contract-based integration",
)

APPROVED_TERMS = (
    "integrado nativamente",
    "integrada nativamente",
    "integrados nativamente",
    "integradas nativamente",
    "componente nativo del ecosistema sgoda-puinave",
    "componente institucional del núcleo sgoda",
    "motor institucional",
    "servicio institucional",
    "módulo nativo",
    "subsistema institucional",
)

DEFAULT_OPEN_TECHNOLOGIES = (
    "python",
    "fastapi",
    "postgresql",
    "flutter",
    "n8n community",
    "git",
    "github",
    "audacity",
    "whisper local",
    "ollama",
    "llama.cpp",
    "sqlite",
    "json",
    "markdown",
)


def is_native_spt(code: str) -> bool:
    match = _NATIVE_SPT.fullmatch(
        str(code or "").strip().upper()
    )

    if match is None:
        return False

    return int(match.group("number")) >= 7


def normalize_native_metadata(
    payload: dict[str, Any],
) -> dict[str, Any]:
    normalized = dict(payload)
    code = str(
        normalized.get("increment_code") or ""
    ).strip().upper()

    if is_native_spt(code):
        normalized["ecosystem_role"] = (
            "native_component"
        )
        normalized["native_ecosystem"] = True
        normalized[
            "mandatory_proprietary_dependencies"
        ] = []
        normalized.setdefault(
            "technology_policy",
            "free_open_optional_proprietary",
        )

    return normalized