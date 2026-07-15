"""Instrumentación automática y tolerante a fallos del historial."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .collector import OperationCollectionError
from .history import HistoryService
from .history_store import HistoryStoreError


def record_event_safely(
    workspace: str | Path,
    event_type: str,
    *,
    details: dict[str, Any] | None = None,
) -> bool:
    """Registra un evento sin alterar el resultado de la operación principal.

    Devuelve ``True`` cuando el evento fue persistido y ``False`` cuando el
    proyecto todavía no permite construir un ``OperationStatus`` o el almacén
    no está disponible.
    """
    try:
        HistoryService(workspace).record(
            event_type,
            details=details,
        )
    except (
        HistoryStoreError,
        OperationCollectionError,
        OSError,
        TypeError,
        ValueError,
    ):
        return False
    return True
