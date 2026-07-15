"""Infraestructura común de observabilidad SGODA."""

from .collector import OperationCollectionError, OperationCollector
from .health import calculate_health
from .models import (
    AuditSnapshot,
    ExtensionSnapshot,
    HealthStatus,
    LifecycleSnapshot,
    OperationStatus,
    ProjectSnapshot,
    ResourceSnapshot,
)
from .serializers import serialize_json, serialize_text
from .status import render_status

__all__ = [
    "AuditSnapshot",
    "ExtensionSnapshot",
    "HealthStatus",
    "LifecycleSnapshot",
    "OperationCollectionError",
    "OperationCollector",
    "OperationStatus",
    "ProjectSnapshot",
    "ResourceSnapshot",
    "calculate_health",
    "render_status",
    "serialize_json",
    "serialize_text",
]

from .history import HistoryService
from .history_models import HistoryEvent
from .history_serializers import history_to_json, history_to_text
from .history_store import HistoryStore, HistoryStoreError

__all__ += [
    "HistoryEvent",
    "HistoryService",
    "HistoryStore",
    "HistoryStoreError",
    "history_to_json",
    "history_to_text",
]

from .instrumentation import record_event_safely

__all__ += ["record_event_safely"]
