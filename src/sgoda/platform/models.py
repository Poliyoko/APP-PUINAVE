"""Contratos canónicos de SPT-010."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class PlatformRequest:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)
    session_id: str = "anonymous"
    language: str = "es"
    context_node_id: str | None = None


@dataclass(frozen=True, slots=True)
class PlatformResponse:
    operation: str
    status: str
    data: dict[str, Any]
    sources: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    no_invention: bool = True


@dataclass(frozen=True, slots=True)
class Capability:
    code: str
    name: str
    version: str
    enabled: bool
    operations: tuple[str, ...]
    dependencies: tuple[str, ...] = ()