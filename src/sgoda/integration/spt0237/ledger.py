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


class InstitutionalAuditLedger:
    """Append-only logical ledger with chained SHA-256 integrity."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _load(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        data = json.loads(self.path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise ValueError("Audit ledger must be a JSON array.")
        self.verify(data)
        return data

    @staticmethod
    def verify(entries: list[dict[str, Any]]) -> bool:
        previous_hash = "GENESIS"
        for sequence, entry in enumerate(entries, start=1):
            if int(entry.get("sequence", 0)) != sequence:
                raise ValueError("Audit ledger sequence mismatch.")
            if str(entry.get("previous_hash") or "") != previous_hash:
                raise ValueError("Audit ledger previous_hash mismatch.")

            body = {
                "sequence": sequence,
                "event_type": str(entry.get("event_type") or ""),
                "payload": dict(entry.get("payload") or {}),
                "previous_hash": previous_hash,
            }
            expected = hashlib.sha256(_canonical(body)).hexdigest().upper()
            if str(entry.get("entry_sha256") or "") != expected:
                raise ValueError("Audit ledger SHA-256 mismatch.")
            previous_hash = expected
        return True

    def append(
        self,
        *,
        event_type: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        event_type = str(event_type or "").strip()
        if not event_type:
            raise ValueError("event_type is required.")

        entries = self._load()
        previous_hash = entries[-1]["entry_sha256"] if entries else "GENESIS"
        body = {
            "sequence": len(entries) + 1,
            "event_type": event_type,
            "payload": dict(payload),
            "previous_hash": previous_hash,
        }
        entry = dict(body)
        entry["entry_sha256"] = hashlib.sha256(
            _canonical(body)
        ).hexdigest().upper()
        entries.append(entry)

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(entries, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        self.verify(entries)
        return entry

    def all(self) -> list[dict[str, Any]]:
        return self._load()
