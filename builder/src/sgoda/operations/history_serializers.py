"""Serializadores del historial de eventos."""

from __future__ import annotations

import json
from pathlib import Path

from .history_models import HistoryEvent


def history_to_text(
    workspace: str | Path,
    events: list[HistoryEvent],
) -> str:
    lines = [
        "Historial SGODA",
        f"Proyecto: {Path(workspace).expanduser().resolve()}",
        "-" * 60,
    ]
    if not events:
        lines.append("[INFO] No hay eventos registrados.")
    else:
        for event in events:
            lines.append(
                f"{event.occurred_at}  {event.event_type}  "
                f"[{event.health}]"
            )
    lines.extend(
        [
            "-" * 60,
            f"Eventos: {len(events)}",
        ]
    )
    return "\n".join(lines)


def history_to_json(events: list[HistoryEvent]) -> str:
    return json.dumps(
        {
            "count": len(events),
            "events": [event.to_dict() for event in events],
        },
        ensure_ascii=False,
        indent=2,
    )
