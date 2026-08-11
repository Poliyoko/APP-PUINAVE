from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Iterable, Mapping


ALLOWED_DECISIONS = frozenset({"RETAIN", "ROTATE", "REVOKE", "REVIEW"})


def build_key_recertification_record(
    key_id: str,
    version: int,
    last_reviewed_at: str,
    review_period_days: int = 90,
    now: datetime | None = None,
) -> dict:
    if now is None:
        now = datetime.now(timezone.utc)

    reviewed = datetime.fromisoformat(last_reviewed_at.replace("Z", "+00:00"))
    due_at = reviewed + timedelta(days=int(review_period_days))
    overdue = due_at <= now

    return {
        "key_id": key_id,
        "version": int(version),
        "last_reviewed_at": reviewed.isoformat(),
        "review_period_days": int(review_period_days),
        "due_at": due_at.isoformat(),
        "overdue": overdue,
        "decision": "REVIEW" if overdue else "RETAIN",
        "rotation_executed": False,
        "revocation_executed": False,
        "key_material_read": False,
        "secret_values_exposed": False,
    }


def validate_recertification(records: Iterable[Mapping]) -> bool:
    records = list(records)
    if not records:
        return False

    return all(
        item.get("decision") in ALLOWED_DECISIONS
        and item.get("rotation_executed") is False
        and item.get("revocation_executed") is False
        and item.get("key_material_read") is False
        and item.get("secret_values_exposed") is False
        for item in records
    )
