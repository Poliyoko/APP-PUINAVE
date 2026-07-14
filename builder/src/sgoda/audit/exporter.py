"""Persistencia de informes de auditoría."""

from pathlib import Path

from .report import AuditReport


class AuditExportError(RuntimeError):
    """Error al escribir un informe."""


def render_report(report: AuditReport, output_format: str) -> str:
    """Renderiza un informe en el formato solicitado."""
    if output_format == "json":
        return report.to_json()
    if output_format == "markdown":
        return report.to_markdown()
    if output_format == "text":
        return report.to_text()
    raise ValueError(f"Formato no soportado: {output_format}")


def save_report(
    report: AuditReport,
    output_path: str | Path,
    *,
    output_format: str,
) -> Path:
    """Guarda un informe creando directorios intermedios."""
    path = Path(output_path).expanduser().resolve()

    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            render_report(report, output_format) + (
                "" if output_format == "markdown" else "\n"
            ),
            encoding="utf-8",
        )
    except OSError as exc:
        raise AuditExportError(
            f"No fue posible guardar el informe en {path}: {exc}"
        ) from exc

    return path
