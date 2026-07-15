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
