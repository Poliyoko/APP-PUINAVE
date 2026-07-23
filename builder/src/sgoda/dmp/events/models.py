"""Eventos emitidos por el subsistema DMP."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any
from uuid import uuid4

from sgoda.dmp.domain.models import utc_now


@dataclass(frozen=True, slots=True)
class DmpEvent:
    event_id: str
    event_type: str
    aggregate_id: str
    occurred_at: str
    payload: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def create(
        cls,
        *,
        event_type: str,
        aggregate_id: str,
        payload: dict[str, Any] | None = None,
    ) -> "DmpEvent":
        return cls(
            event_id=str(uuid4()),
            event_type=event_type,
            aggregate_id=aggregate_id,
            occurred_at=utc_now(),
            payload=payload or {},
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
