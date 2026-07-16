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


from .report_builder import ExecutiveReportBuilder
from .report_models import ExecutiveRecommendation, ExecutiveReport
from .report_serializers import report_to_html, report_to_json, report_to_markdown
from .report_service import (
    ExecutiveReportExportError,
    render_executive_report,
    save_executive_report,
)

__all__ += [
    "ExecutiveRecommendation",
    "ExecutiveReport",
    "ExecutiveReportBuilder",
    "ExecutiveReportExportError",
    "render_executive_report",
    "report_to_html",
    "report_to_json",
    "report_to_markdown",
    "save_executive_report",
    "ALL_SECTIONS",
    "PROFILE_SECTIONS",
    "ReportProfileError",
    "resolve_sections",
]


from .report_profiles import (
    ALL_SECTIONS,
    PROFILE_SECTIONS,
    ReportProfileError,
    resolve_sections,
)
