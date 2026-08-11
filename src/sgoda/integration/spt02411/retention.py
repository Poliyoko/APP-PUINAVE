from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Mapping


def build_retention_decision(
    profile: Mapping,
    now: datetime | None = None,
) -> dict:
    if now is None:
        now = datetime.now(timezone.utc)

    created_at = datetime.fromisoformat(
        str(profile.get("created_at", "")).replace("Z", "+00:00")
    )

    retention_days = int(profile.get("retention_days", 0))
    legal_hold = bool(profile.get("legal_hold", False))

    expires_at = created_at + timedelta(days=retention_days)
    expired = expires_at <= now

    if legal_hold:
        decision = "RETAIN_LEGAL_HOLD"
    elif expired:
        decision = "DISPOSE_REVIEW"
    else:
        decision = "RETAIN"

    valid = retention_days > 0

    return {
        "valid": valid,
        "retention_days": retention_days,
        "legal_hold": legal_hold,
        "expires_at": expires_at.isoformat(),
        "expired": expired,
        "decision": decision,
        "disposal_executed": False,
        "data_modified_in_production": False,
        "secret_values_exposed": False,
    }
