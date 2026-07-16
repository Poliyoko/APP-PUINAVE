"""Servicio de aplicación para reportes ejecutivos."""

from __future__ import annotations

from pathlib import Path

from .report_builder import ExecutiveReportBuilder
from .report_serializers import report_to_html, report_to_json, report_to_markdown


class ExecutiveReportExportError(RuntimeError):
    """Error controlado durante la exportación de reportes."""


def render_executive_report(
    workspace: str | Path,
    *,
    output_format: str = "markdown",
    include_history: bool = True,
    history_limit: int = 20,
    profile: str = "executive",
    sections: tuple[str, ...] | None = None,
) -> str:
    report = ExecutiveReportBuilder(workspace).build(
        include_history=include_history,
        history_limit=history_limit,
        profile=profile,
        sections=sections,
    )
    if output_format == "json":
        return report_to_json(report)
    if output_format == "markdown":
        return report_to_markdown(report)
    if output_format == "html":
        return report_to_html(report)
    raise ValueError(f"Formato de reporte no soportado: {output_format}")


def save_executive_report(
    content: str,
    output: str | Path,
    *,
    output_format: str,
) -> Path:
    destination = Path(output).expanduser().resolve()

    if destination.suffix:
        file_path = destination
    else:
        filename = (
            "executive-report.json"
            if output_format == "json"
            else "executive-report.html"
            if output_format == "html"
            else "executive-report.md"
        )
        file_path = destination / filename

    try:
        file_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = file_path.with_suffix(file_path.suffix + ".tmp")
        temporary.write_text(content + "\n", encoding="utf-8")
        temporary.replace(file_path)
    except OSError as exc:
        raise ExecutiveReportExportError(
            f"No fue posible guardar el reporte: {exc}"
        ) from exc

    return file_path
