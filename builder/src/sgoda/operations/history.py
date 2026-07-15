"""Servicio de historial construido sobre OperationCollector."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from sgoda import __version__

from .collector import OperationCollector
from .history_models import HistoryEvent
from .history_store import HistoryStore


class HistoryService:
    """Registra eventos usando OperationStatus como contexto."""

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.store = HistoryStore(self.workspace)

    def record(
        self,
        event_type: str,
        *,
        details: dict[str, Any] | None = None,
    ) -> HistoryEvent:
        status = OperationCollector(self.workspace).collect()
        event = HistoryEvent.create(
            event_type=event_type,
            occurred_at=datetime.now(UTC).isoformat(),
            actor="SGODA Project Builder",
            builder_version=__version__,
            project_name=status.project.name,
            schema_version=status.project.schema_version,
            health=status.health,
            details=details,
        )
        self.store.append(event)
        return event

    def list(
        self,
        *,
        event_type: str | None = None,
        since: str | None = None,
        limit: int | None = None,
    ) -> list[HistoryEvent]:
        return self.store.query(
            event_type=event_type,
            since=since,
            limit=limit,
        )
