import hashlib
import json
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Any, Dict, List


@dataclass(frozen=True)
class TraceabilityRecord:
    sequence: int
    event_name: str
    payload: Dict[str, Any]
    previous_hash: str
    record_hash: str
    occurred_at_utc: str


class TraceabilityLedger:
    def __init__(self) -> None:
        self._records: List[TraceabilityRecord] = []

    def append(self, event_name: str, payload: Dict[str, Any]) -> TraceabilityRecord:
        previous_hash = self._records[-1].record_hash if self._records else "GENESIS"
        occurred_at = datetime.now(timezone.utc).isoformat()
        raw = json.dumps(
            {
                "sequence": len(self._records) + 1,
                "event_name": event_name,
                "payload": payload,
                "previous_hash": previous_hash,
                "occurred_at_utc": occurred_at,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        record_hash = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        record = TraceabilityRecord(
            sequence=len(self._records) + 1,
            event_name=event_name,
            payload=dict(payload),
            previous_hash=previous_hash,
            record_hash=record_hash,
            occurred_at_utc=occurred_at,
        )
        self._records.append(record)
        return record

    def records(self):
        return tuple(self._records)

    def verify(self) -> bool:
        previous_hash = "GENESIS"
        for index, record in enumerate(self._records, start=1):
            if record.sequence != index:
                return False
            if record.previous_hash != previous_hash:
                return False
            previous_hash = record.record_hash
        return True