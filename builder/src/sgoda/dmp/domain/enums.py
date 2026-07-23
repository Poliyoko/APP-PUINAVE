"""Enumeraciones compartidas por el dominio DMP."""

from __future__ import annotations

from enum import StrEnum


class WorkStatus(StrEnum):
    PLANNED = "planned"
    IN_PROGRESS = "in_progress"
    BLOCKED = "blocked"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


ALLOWED_WORK_STATUS_TRANSITIONS: dict[
    WorkStatus, frozenset[WorkStatus]
] = {
    WorkStatus.PLANNED: frozenset(
        {
            WorkStatus.IN_PROGRESS,
            WorkStatus.CANCELLED,
        }
    ),
    WorkStatus.IN_PROGRESS: frozenset(
        {
            WorkStatus.BLOCKED,
            WorkStatus.COMPLETED,
            WorkStatus.CANCELLED,
        }
    ),
    WorkStatus.BLOCKED: frozenset(
        {
            WorkStatus.IN_PROGRESS,
            WorkStatus.CANCELLED,
        }
    ),
    WorkStatus.COMPLETED: frozenset(),
    WorkStatus.CANCELLED: frozenset(),
}


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
