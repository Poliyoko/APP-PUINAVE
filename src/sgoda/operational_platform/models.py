"""Modelos canónicos de SPT-011."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class OperationalRequest:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)
    session_id: str = "anonymous"
    language: str = "es"
    entry_id: str | None = None


@dataclass(frozen=True, slots=True)
class OperationalResponse:
    operation: str
    status: str
    data: dict[str, Any]
    sources: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    no_invention: bool = True


@dataclass(frozen=True, slots=True)
class RuntimeStatus:
    database_mode: str
    rlb_loaded: bool
    media_loaded: bool
    n8n_enabled: bool
    flutter_contract_enabled: bool
    api_enabled: bool