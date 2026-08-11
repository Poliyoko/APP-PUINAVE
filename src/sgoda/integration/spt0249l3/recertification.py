from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Iterable, Mapping


ALLOWED_DECISIONS = frozenset({"RETAIN", "REVOKE", "REVIEW"})


def build_recertification_record(
    identity_id: str,
    permission: str,
    last_reviewed_at: str,
    review_period_days: int = 90,
    now: datetime | None = None,
) -> dict:
    if now is None:
        now = datetime.now(timezone.utc)

    reviewed = datetime.fromisoformat(last_reviewed_at.replace("Z", "+00:00"))
    due_at = reviewed + timedelta(days=int(review_period_days))
    overdue = due_at <= now

    decision = "REVIEW" if overdue else "RETAIN"

    return {
        "identity_id": identity_id,
        "permission": permission,
        "last_reviewed_at": reviewed.isoformat(),
        "review_period_days": int(review_period_days),
        "due_at": due_at.isoformat(),
        "overdue": overdue,
        "decision": decision,
        "executed": False,
        "secret_values_exposed": False,
    }


def validate_recertification(records: Iterable[Mapping]) -> bool:
    records = list(records)
    if not records:
        return False

    return all(
        record.get("decision") in ALLOWED_DECISIONS
        and record.get("executed") is False
        and record.get("secret_values_exposed") is False
        for record in records
    )
