import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


class InstitutionalEvidenceWriter:
    def __init__(self, output_path) -> None:
        self.output_path = Path(output_path)
        self._entries: List[Dict[str, Any]] = []

    def record(self, event_name: str, payload: Dict[str, Any]) -> None:
        self._entries.append(
            {
                "event_name": event_name,
                "payload": dict(payload),
                "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
            }
        )
        self.flush()

    def flush(self) -> None:
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.output_path.with_suffix(self.output_path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(
                {
                    "schema": "sgoda.spt0193.evidence.v1",
                    "entries": self._entries,
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        temporary.replace(self.output_path)

    @property
    def entries(self):
        return tuple(self._entries)