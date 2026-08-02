"""Resolución canónica institucional para SGD-116B."""

from __future__ import annotations

import re
from dataclasses import dataclass


SUPPORTED_PREFIXES = ("ADR", "SGD", "SPB", "SPT", "SIB", "MMGR")

_CANONICAL_RE = re.compile(
    r"^(?P<code>(?:ADR|SGD|SPB|SPT|SIB|MMGR)-"
    r"[0-9]+(?:\.[0-9]+)?[A-Z]?)"
    r"(?P<version>-v[0-9]+(?:\.[0-9]+)*(?:[-._A-Za-z0-9]*)?)?$",
    re.IGNORECASE,
)


@dataclass(frozen=True, slots=True)
class AliasResolution:
    raw: str
    canonical: str
    changed: bool
    valid_format: bool


def resolve_alias(value: object) -> AliasResolution:
    raw = str(value or "").strip()

    if not raw:
        return AliasResolution(
            raw="",
            canonical="",
            changed=False,
            valid_format=False,
        )

    token = raw.split()[0].rstrip(",;:")
    match = _CANONICAL_RE.fullmatch(token)

    if not match:
        return AliasResolution(
            raw=raw,
            canonical=token.upper(),
            changed=False,
            valid_format=False,
        )

    canonical = match.group("code").upper()

    return AliasResolution(
        raw=raw,
        canonical=canonical,
        changed=canonical != token.upper(),
        valid_format=True,
    )


def canonical_component_code(value: object) -> str:
    return resolve_alias(value).canonical


def is_supported_component_code(value: object) -> bool:
    resolution = resolve_alias(value)
    return resolution.valid_format and bool(resolution.canonical)