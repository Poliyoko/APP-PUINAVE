"""Enumeraciones compartidas por el dominio DMP."""

from __future__ import annotations

from enum import StrEnum


class WorkStatus(StrEnum):
    PLANNED = "planned"
    IN_PROGRESS = "in_progress"
    BLOCKED = "blocked"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class EvidenceType(StrEnum):
    COMMIT = "commit"
    TEST = "test"
    BUILD = "build"
    DOCUMENT = "document"
    LOG = "log"
    RELEASE = "release"
    OTHER = "other"


class RiskLevel(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ChangeStatus(StrEnum):
    PROPOSED = "proposed"
    APPROVED = "approved"
    REJECTED = "rejected"
    IMPLEMENTED = "implemented"
