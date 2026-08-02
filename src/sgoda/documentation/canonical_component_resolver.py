"""Resolvedor canónico documental SGD-115A."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Iterable


_VERSIONED_CODE = re.compile(
    r"^(?P<canonical>[A-Z]+-\d+[A-Z]?)-v"
    r"(?P<version>\d+(?:\.\d+)*)$",
    re.IGNORECASE,
)


@dataclass(frozen=True, slots=True)
class CanonicalComponent:
    canonical_code: str
    active_record: dict[str, Any]
    history: tuple[dict[str, Any], ...]


def version_tuple(value: str) -> tuple[int, ...]:
    parts = []

    for token in str(value or "0").split("."):
        try:
            parts.append(int(token))
        except ValueError:
            parts.append(0)

    return tuple(parts)


def canonical_code(record: dict[str, Any]) -> str:
    explicit = str(
        record.get("canonical_code") or ""
    ).strip().upper()

    if explicit:
        return explicit

    code = str(
        record.get("increment_code") or ""
    ).strip().upper()

    match = _VERSIONED_CODE.fullmatch(code)

    if match:
        return match.group("canonical").upper()

    return code


def record_version(record: dict[str, Any]) -> str:
    explicit = str(record.get("version") or "").strip()

    if explicit:
        return explicit

    code = str(
        record.get("increment_code") or ""
    ).strip().upper()

    match = _VERSIONED_CODE.fullmatch(code)

    return match.group("version") if match else "0"


def consolidate_components(
    records: Iterable[dict[str, Any]],
) -> tuple[CanonicalComponent, ...]:
    grouped: dict[str, list[dict[str, Any]]] = {}

    for raw in records:
        record = dict(raw)
        code = canonical_code(record)

        if not code:
            continue

        grouped.setdefault(code, []).append(record)

    result = []

    for code in sorted(grouped):
        versions = sorted(
            grouped[code],
            key=lambda item: (
                version_tuple(record_version(item)),
                str(item.get("config_path") or ""),
            ),
            reverse=True,
        )

        active = dict(versions[0])
        active["canonical_code"] = code
        active["active_version"] = record_version(active)

        history = []

        for item in versions[1:]:
            historical = dict(item)
            historical["canonical_code"] = code
            historical["historical_version"] = record_version(
                historical
            )
            history.append(historical)

        result.append(
            CanonicalComponent(
                canonical_code=code,
                active_record=active,
                history=tuple(history),
            )
        )

    return tuple(result)


def duplicate_canonical_codes(
    records: Iterable[dict[str, Any]],
) -> tuple[str, ...]:
    consolidated = consolidate_components(records)

    return tuple(
        item.canonical_code
        for item in consolidated
        if not item.active_record
    )