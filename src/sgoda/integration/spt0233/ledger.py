from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


class CategoryChangeLedger:
    """Ledger JSONL append-only con encadenamiento SHA-256."""

    GENESIS = "0" * 64

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def read(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []

        events: list[dict[str, Any]] = []
        for line in self.path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                events.append(json.loads(line))
        return events

    @classmethod
    def _event_hash(cls, event_without_hash: dict[str, Any]) -> str:
        return hashlib.sha256(_canonical(event_without_hash)).hexdigest().upper()

    def verify(self) -> bool:
        previous = self.GENESIS

        for expected_sequence, event in enumerate(self.read(), start=1):
            if int(event.get("sequence", 0)) != expected_sequence:
                return False
            if str(event.get("previous_hash") or "") != previous:
                return False

            recorded_hash = str(event.get("event_hash") or "").upper()
            body = dict(event)
            body.pop("event_hash", None)
            calculated = self._event_hash(body)

            if recorded_hash != calculated:
                return False

            previous = recorded_hash

        return True

    def append(
        self,
        *,
        action: str,
        proposal_id: str,
        reviewer: str,
        reason: str,
        registry_version_before: int,
        registry_version_after: int,
        registry_sha_before: str,
        registry_sha_after: str,
        category_id: str | None,
    ) -> dict[str, Any]:
        if not self.verify():
            raise ValueError("Category change ledger integrity check failed.")

        existing = self.read()
        previous_hash = (
            self.GENESIS
            if not existing
            else str(existing[-1]["event_hash"]).upper()
        )

        event = {
            "sequence": len(existing) + 1,
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
            "previous_hash": previous_hash,
            "action": str(action),
            "proposal_id": str(proposal_id),
            "reviewer": str(reviewer),
            "reason": str(reason),
            "registry_version_before": int(registry_version_before),
            "registry_version_after": int(registry_version_after),
            "registry_sha_before": str(registry_sha_before),
            "registry_sha_after": str(registry_sha_after),
            "category_id": category_id,
        }
        event["event_hash"] = self._event_hash(event)

        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(
                json.dumps(event, ensure_ascii=False, sort_keys=True)
                + "\n"
            )

        if not self.verify():
            raise ValueError("Category change ledger failed post-append verification.")

        return event
