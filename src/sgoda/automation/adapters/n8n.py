"""Publicación de eventos compatible con n8n."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class PublicadorEventosArchivo:
    def __init__(self, output_path: str | Path) -> None:
        self.output_path = Path(output_path)

    def publish(
        self,
        *,
        event_type: str,
        payload: dict[str, Any],
    ) -> None:
        self.output_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        envelope = {
            "event_type": event_type,
            "occurred_at_utc": datetime.now(
                timezone.utc
            ).isoformat(),
            "source": "sgoda.automation.adapters",
            "payload": payload,
            "n8n_compatible": True,
        }

        with self.output_path.open(
            "a",
            encoding="utf-8",
        ) as stream:
            stream.write(
                json.dumps(
                    envelope,
                    ensure_ascii=False,
                )
                + "\n"
            )