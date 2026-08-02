"""Modelos del Asistente Inteligente Institucional SPT-004A."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class FuenteRespuesta:
    source_type: str
    source_id: str
    label: str
    path: str | None = None
    validated: bool = True


@dataclass(slots=True)
class ConsultaAsistente:
    question: str
    language: str = "es"
    user_role: str = "visitor"
    session_id: str | None = None


@dataclass(slots=True)
class RespuestaAsistente:
    answer: str
    intent: str
    confidence: float
    validated: bool
    found: bool
    sources: list[FuenteRespuesta] = field(default_factory=list)
    suggestions: list[str] = field(default_factory=list)
    data: dict[str, Any] = field(default_factory=dict)
    requires_human_review: bool = False