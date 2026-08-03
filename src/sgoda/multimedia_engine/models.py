"""Modelos institucionales del Motor Multimedia Inteligente."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class MediaResource:
    resource_id: str
    entry_id: str
    media_type: str
    language: str
    uri: str
    format: str
    validated: bool = False
    autoplay: bool = False
    duration_seconds: float | None = None
    checksum: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class MultimediaCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class MultimediaResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True