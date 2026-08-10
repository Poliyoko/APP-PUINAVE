from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


class OrchestrationEventLedger:
    """Ledger local append-only lÃ³gico con hash encadenado."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _load(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        data = json.loads(self.path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise ValueError("Event ledger must be a JSON array.")
        self.verify(data)
        return data

    @staticmethod
    def verify(events: list[dict[str, Any]]) -> bool:
        previous = "GENESIS"
        for index, event in enumerate(events, start=1):
            if int(event.get("sequence", 0)) != index:
                raise ValueError("Event sequence is not contiguous.")
            if str(event.get("previous_hash") or "") != previous:
                raise ValueError("Event previous_hash mismatch.")

            body = {
                "sequence": index,
                "orchestration_id": str(event.get("orchestration_id") or ""),
                "event_type": str(event.get("event_type") or ""),
                "payload": dict(event.get("payload") or {}),
                "previous_hash": previous,
            }
            expected = hashlib.sha256(_canonical(body)).hexdigest().upper()
            if str(event.get("event_sha256") or "") != expected:
                raise ValueError("Event SHA-256 mismatch.")
            previous = expected
        return True

    def append(
        self,
        *,
        orchestration_id: str,
        event_type: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        orchestration_id = str(orchestration_id or "").strip()
        event_type = str(event_type or "").strip()
        if not orchestration_id or not event_type:
            raise ValueError("orchestration_id and event_type are required.")

        events = self._load()
        previous = events[-1]["event_sha256"] if events else "GENESIS"
        sequence = len(events) + 1
        body = {
            "sequence": sequence,
            "orchestration_id": orchestration_id,
            "event_type": event_type,
            "payload": dict(payload),
            "previous_hash": previous,
        }
        event = dict(body)
        event["event_sha256"] = hashlib.sha256(
            _canonical(body)
        ).hexdigest().upper()
        events.append(event)

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(events, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        self.verify(events)
        return event

    def all(self) -> list[dict[str, Any]]:
        return self._load()
