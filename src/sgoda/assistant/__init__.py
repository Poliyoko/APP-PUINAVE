"""Asistente Inteligente Institucional SGODA-PUINAVE."""

from __future__ import annotations

from typing import Any

__all__ = [
    "ConsultaAsistente",
    "FuenteRespuesta",
    "InstitutionalAssistant",
    "KnowledgeRepository",
    "RespuestaAsistente",
    "classify_intent",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "ConsultaAsistente",
        "FuenteRespuesta",
        "RespuestaAsistente",
    }:
        from . import models
        return getattr(models, name)

    if name == "KnowledgeRepository":
        from . import knowledge_repository
        return getattr(knowledge_repository, name)

    if name == "InstitutionalAssistant":
        from . import service
        return getattr(service, name)

    if name == "classify_intent":
        from . import intent_classifier
        return getattr(intent_classifier, name)

    raise AttributeError(name)