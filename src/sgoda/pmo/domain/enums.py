"""Enumeraciones de la Plataforma de Gobierno Documental PMO."""

from __future__ import annotations

from enum import StrEnum


class PmoStatus(StrEnum):
    """Estados normalizados del portafolio PMO."""

    PLANNED = "planned"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    COMPLETED_DECLARED = "completed_declared"
    COMPLETED_VERIFIED = "completed_verified"
    BLOCKED = "blocked"
    CANCELLED = "cancelled"


class RiskLevel(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class KpiState(StrEnum):
    ON_TRACK = "on_track"
    AT_RISK = "at_risk"
    OFF_TRACK = "off_track"


class ArtifactType(StrEnum):
    DASHBOARD = "dashboard"
    DMP = "dmp"
    EXECUTIVE_REPORT = "executive_report"
    PRESENTATION = "presentation"
    TECHNICAL_DOCUMENT = "technical_document"
    DELIVERABLE_CATALOG = "deliverable_catalog"
