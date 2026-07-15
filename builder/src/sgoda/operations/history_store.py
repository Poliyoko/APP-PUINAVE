"""Almacén JSONL append-only para eventos SGODA."""

from __future__ import annotations

from datetime import datetime
import json
from pathlib import Path
from typing import Iterable

from .history_models import HistoryEvent


class HistoryStoreError(RuntimeError):
    """Error controlado del almacén de historial."""


class HistoryStore:
    """Persiste eventos en formato JSON Lines UTF-8."""

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.history_dir = self.workspace / ".sgoda" / "history"
        self.events_path = self.history_dir / "events.jsonl"

    def append(self, event: HistoryEvent) -> None:
        self.history_dir.mkdir(parents=True, exist_ok=True)
        line = json.dumps(
            event.to_dict(),
            ensure_ascii=False,
            separators=(",", ":"),
        )
        with self.events_path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(line + "\n")

    def read_all(self) -> list[HistoryEvent]:
        if not self.events_path.is_file():
            return []

        events: list[HistoryEvent] = []
        try:
            lines = self.events_path.read_text(encoding="utf-8-sig").splitlines()
        except OSError as exc:
            raise HistoryStoreError(f"No fue posible leer el historial: {exc}") from exc

        for index, line in enumerate(lines, start=1):
            if not line.strip():
                continue
            try:
                payload = json.loads(line)
                if not isinstance(payload, dict):
                    raise ValueError("el evento debe ser un objeto JSON")
                events.append(HistoryEvent.from_dict(payload))
            except (json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
                raise HistoryStoreError(
                    f"Evento corrupto en línea {index}: {exc}"
                ) from exc

        return sorted(events, key=lambda item: (item.occurred_at, item.event_id))

    def query(
        self,
        *,
        event_type: str | None = None,
        since: str | None = None,
        limit: int | None = None,
    ) -> list[HistoryEvent]:
        events = self.read_all()

        if event_type:
            events = [item for item in events if item.event_type == event_type]

        if since:
            try:
                since_value = datetime.fromisoformat(since)
            except ValueError as exc:
                raise HistoryStoreError(
                    f"Fecha --since inválida: {since}"
                ) from exc

            filtered: list[HistoryEvent] = []
            for item in events:
                try:
                    occurred = datetime.fromisoformat(item.occurred_at)
                except ValueError as exc:
                    raise HistoryStoreError(
                        f"Fecha de evento inválida: {item.occurred_at}"
                    ) from exc
                if occurred >= since_value:
                    filtered.append(item)
            events = filtered

        if limit is not None:
            if limit < 1:
                raise HistoryStoreError("--limit debe ser mayor que cero.")
            events = events[-limit:]

        return events
