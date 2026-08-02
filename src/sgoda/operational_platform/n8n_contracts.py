"""Contratos de automatización n8n."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class N8nEvent:
    event_type: str
    payload: dict[str, Any]
    idempotency_key: str


def lexical_entry_event(
    entry_id: str,
    operation: str,
) -> N8nEvent:
    normalized_operation = operation.strip().casefold()

    if normalized_operation not in {
        "created",
        "updated",
        "validated",
        "enrichment_requested",
    }:
        raise ValueError(
            f"Operación n8n no permitida: {operation}"
        )

    return N8nEvent(
        event_type=f"sgoda.lexical.{normalized_operation}",
        payload={
            "entry_id": entry_id,
            "operation": normalized_operation,
        },
        idempotency_key=(
            f"sgoda:{entry_id}:{normalized_operation}"
        ),
    )