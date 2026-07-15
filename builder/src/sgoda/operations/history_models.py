"""Modelos de eventos y consultas del historial SGODA."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any
from uuid import uuid4


@dataclass(frozen=True, slots=True)
class HistoryEvent:
    event_id: str
    event_type: str
    occurred_at: str
    actor: str
    builder_version: str
    project_name: str
    schema_version: str
    health: str
    details: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def create(
        cls,
        *,
        event_type: str,
        occurred_at: str,
        actor: str,
        builder_version: str,
        project_name: str,
        schema_version: str,
        health: str,
        details: dict[str, Any] | None = None,
    ) -> "HistoryEvent":
        return cls(
            event_id=str(uuid4()),
            event_type=event_type,
            occurred_at=occurred_at,
            actor=actor,
            builder_version=builder_version,
            project_name=project_name,
            schema_version=schema_version,
            health=health,
            details=details or {},
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "HistoryEvent":
        return cls(
            event_id=str(payload["event_id"]),
            event_type=str(payload["event_type"]),
            occurred_at=str(payload["occurred_at"]),
            actor=str(payload["actor"]),
            builder_version=str(payload["builder_version"]),
            project_name=str(payload["project_name"]),
            schema_version=str(payload["schema_version"]),
            health=str(payload["health"]),
            details=dict(payload.get("details", {})),
        )
