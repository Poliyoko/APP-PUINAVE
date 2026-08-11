from __future__ import annotations
from datetime import datetime, timezone
from typing import Mapping


VALID_STATES = frozenset({
    "PLANNED",
    "ACTIVE",
    "ROTATION_DUE",
    "RETIRED",
    "REVOKED",
    "DESTROYED",
})

ALLOWED_TRANSITIONS = {
    "PLANNED": frozenset({"ACTIVE", "REVOKED"}),
    "ACTIVE": frozenset({"ROTATION_DUE", "RETIRED", "REVOKED"}),
    "ROTATION_DUE": frozenset({"RETIRED", "REVOKED"}),
    "RETIRED": frozenset({"DESTROYED"}),
    "REVOKED": frozenset({"DESTROYED"}),
    "DESTROYED": frozenset(),
}


def transition(record: Mapping, target_state: str) -> dict:
    current = str(record.get("state", "")).upper()
    target = str(target_state).upper()

    if current not in VALID_STATES or target not in VALID_STATES:
        raise ValueError("invalid key lifecycle state")

    if target not in ALLOWED_TRANSITIONS[current]:
        raise ValueError("invalid key lifecycle transition")

    updated = dict(record)
    updated["state"] = target
    return updated


def rotation_due(next_rotation_at: str, now: datetime | None = None) -> bool:
    if now is None:
        now = datetime.now(timezone.utc)

    target = datetime.fromisoformat(next_rotation_at.replace("Z", "+00:00"))
    return target <= now
