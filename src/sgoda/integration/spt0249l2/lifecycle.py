from __future__ import annotations
from datetime import datetime, timezone
from typing import Mapping


VALID_STATES = frozenset({
    "REQUESTED",
    "APPROVED",
    "ACTIVE",
    "SUSPENDED",
    "EXPIRED",
    "REVOKED",
    "CLOSED",
})


ALLOWED_TRANSITIONS = {
    "REQUESTED": frozenset({"APPROVED", "REVOKED"}),
    "APPROVED": frozenset({"ACTIVE", "REVOKED"}),
    "ACTIVE": frozenset({"SUSPENDED", "EXPIRED", "REVOKED"}),
    "SUSPENDED": frozenset({"ACTIVE", "REVOKED"}),
    "EXPIRED": frozenset({"CLOSED"}),
    "REVOKED": frozenset({"CLOSED"}),
    "CLOSED": frozenset(),
}


def transition(record: Mapping, new_state: str) -> dict:
    current = str(record.get("state", "")).upper()
    target = str(new_state).upper()

    if current not in VALID_STATES or target not in VALID_STATES:
        raise ValueError("invalid lifecycle state")

    if target not in ALLOWED_TRANSITIONS[current]:
        raise ValueError("invalid lifecycle transition")

    updated = dict(record)
    updated["state"] = target
    return updated


def is_expired(expires_at: str, now: datetime | None = None) -> bool:
    if now is None:
        now = datetime.now(timezone.utc)

    target = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
    return target <= now
