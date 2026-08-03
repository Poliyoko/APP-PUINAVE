"""Modelos compartidos de la Fase Tecnológica IV."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class PhaseCapability:
    code: str
    name: str
    domain: str
    status: str = "planned"
    native: bool = True
    dependencies: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class FoundationRequest:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class FoundationResponse:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True