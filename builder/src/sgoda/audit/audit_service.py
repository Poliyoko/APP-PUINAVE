"""Application service for the SGODA audit subsystem.

The service defined here is intentionally a thin façade. Audit execution,
report rendering, and report persistence remain delegated to the existing
engine and exporter components.
"""

from __future__ import annotations

from pathlib import Path

from .engine import AuditEngine
from .exporter import render_report, save_report
from .report import AuditReport

__all__ = ["AuditService"]


class AuditService:
    """Coordinate audit execution, rendering, and persistence.

    Args:
        engine: Audit engine to use. When omitted, the service creates the
            subsystem's default :class:`AuditEngine`.

    The service does not evaluate rules, construct findings, serialize
    reports, or write files directly. Those responsibilities remain in the
    existing audit subsystem.
    """

    def __init__(self, engine: AuditEngine | None = None) -> None:
        self._engine = engine if engine is not None else AuditEngine()

    def audit(self, workspace: str | Path) -> AuditReport:
        """Audit ``workspace`` and return the resulting report.

        Args:
            workspace: Project workspace accepted by :meth:`AuditEngine.audit`.

        Returns:
            The report produced by the configured audit engine.
        """
        return self._engine.audit(workspace)

    def render(
        self,
        report: AuditReport,
        *,
        output_format: str,
    ) -> str:
        """Render an audit report using the subsystem exporter.

        Args:
            report: Report to render.
            output_format: Format understood by :func:`render_report`.

        Returns:
            Rendered report content.
        """
        return render_report(report, output_format)

    def save(
        self,
        report: AuditReport,
        output_path: str | Path,
        *,
        output_format: str,
    ) -> Path:
        """Persist an audit report using the subsystem exporter.

        Args:
            report: Report to persist.
            output_path: Destination accepted by :func:`save_report`.
            output_format: Format understood by :func:`save_report`.

        Returns:
            Path returned by :func:`save_report`.
        """
        return save_report(
            report,
            output_path,
            output_format=output_format,
        )

    def audit_and_render(
        self,
        workspace: str | Path,
        *,
        output_format: str,
    ) -> str:
        """Audit a workspace and render the generated report."""
        report = self.audit(workspace)
        return self.render(report, output_format=output_format)

    def audit_and_save(
        self,
        workspace: str | Path,
        output_path: str | Path,
        *,
        output_format: str,
    ) -> Path:
        """Audit a workspace and persist the generated report."""
        report = self.audit(workspace)
        return self.save(
            report,
            output_path,
            output_format=output_format,
        )
