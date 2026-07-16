"""Modelos del reporte ejecutivo SGODA."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any

from .history_models import HistoryEvent
from .models import OperationStatus


@dataclass(frozen=True, slots=True)
class ExecutiveRecommendation:
    """Recomendación ejecutiva derivada del estado del proyecto."""

    code: str
    priority: str
    message: str

    def to_dict(self) -> dict[str, str]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class ExecutiveReport:
    """Reporte consolidado construido sobre OperationStatus."""

    title: str
    generated_at: str
    status: OperationStatus
    history: tuple[HistoryEvent, ...] = ()
    recommendations: tuple[ExecutiveRecommendation, ...] = ()
    profile: str = "executive"
    sections: tuple[str, ...] = ()
    indicators: dict[str, Any] = field(default_factory=dict)
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def health(self) -> str:
        return self.status.health

    @property
    def project_name(self) -> str:
        return self.status.project.name

    def to_dict(self) -> dict[str, Any]:
        return {
            "title": self.title,
            "generated_at": self.generated_at,
            "project": asdict(self.status.project),
            "builder_version": self.status.builder_version,
            "workspace": self.status.workspace,
            "health": self.status.health,
            "audit": asdict(self.status.audit),
            "lifecycle": asdict(self.status.lifecycle),
            "components": dict(self.status.components),
            "extensions": asdict(self.status.extensions),
            "resources": {
                **asdict(self.status.resources),
                "available": self.status.resources.available,
                "total": self.status.resources.total,
            },
            "profile": self.profile,
            "sections": list(self.sections),
            "indicators": dict(self.indicators),
            "history": [event.to_dict() for event in self.history],
            "recommendations": [
                recommendation.to_dict()
                for recommendation in self.recommendations
            ],
            "metadata": dict(self.metadata),
        }
