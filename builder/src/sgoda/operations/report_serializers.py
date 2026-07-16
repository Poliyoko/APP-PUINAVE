"""Serializadores Markdown, JSON y HTML para reportes ejecutivos."""

from __future__ import annotations

from html import escape
import json
import re

from .report_models import ExecutiveReport


_BOLD_PATTERN = re.compile(r"\*\*(.+?)\*\*")
_ITALIC_PATTERN = re.compile(r"(?<!\*)\*(.+?)\*(?!\*)")
_CODE_PATTERN = re.compile(r"`([^`]+)`")


def _inline_markdown_to_html(value: str) -> str:
    """Convierte el subconjunto Markdown utilizado por los reportes SGODA."""
    escaped = escape(value)
    escaped = _CODE_PATTERN.sub(r"<code>\1</code>", escaped)
    escaped = _BOLD_PATTERN.sub(r"<strong>\1</strong>", escaped)
    escaped = _ITALIC_PATTERN.sub(r"<em>\1</em>", escaped)
    return escaped


def _yes_no(value: bool) -> str:
    return "OK" if value else "FALTANTE"


def report_to_json(report: ExecutiveReport) -> str:
    return json.dumps(report.to_dict(), ensure_ascii=False, indent=2)


def report_to_markdown(report: ExecutiveReport) -> str:
    status = report.status
    sections = set(report.sections)
    lines = [f"# {report.title}", "", f"_Perfil: {report.profile}_", ""]

    if "summary" in sections:
        lines.extend([
            "## Resumen Ejecutivo", "",
            f"- **Proyecto:** {status.project.name}",
            f"- **Ruta:** `{status.workspace}`",
            f"- **Builder:** {status.builder_version}",
            f"- **Esquema:** {status.project.schema_version}",
            f"- **Estado general:** **{status.health}**",
            f"- **Puntuación:** **{status.audit.score}/100**",
            f"- **Riesgo:** **{report.indicators['risk_level']}**",
            f"- **Generado:** {report.generated_at}", "",
        ])

    if "audit" in sections:
        lines.extend([
            "## Auditoría y Calidad", "",
            "| Indicador | Valor |",
            "|---|---:|",
            f"| Estado | {status.audit.status} |",
            f"| Errores | {status.audit.errors} |",
            f"| Advertencias | {status.audit.warnings} |",
            f"| Información | {status.audit.information} |",
            f"| Controles aprobados | {status.audit.successes} |",
            f"| Cobertura de recursos | {report.indicators['resource_coverage']}% |",
            "",
        ])

    if "components" in sections:
        lines.extend(["## Componentes", ""])
        if status.components:
            lines.extend([
                "| Tipo | Total |",
                "|---|---:|",
                *[
                    f"| {kind} | {total} |"
                    for kind, total in sorted(status.components.items())
                ],
            ])
        else:
            lines.append("_No hay componentes registrados._")
        lines.append("")

    if "extensions" in sections:
        lines.extend([
            "## Extensiones", "",
            f"- Plugins: **{status.extensions.plugins}**",
            f"- Plantillas: **{status.extensions.templates}**",
            f"- Extensiones habilitadas: **{status.extensions.enabled}**", "",
        ])

    if "resources" in sections:
        lines.extend([
            "## Recursos", "",
            f"- Léxico: **{_yes_no(status.resources.lexicon)}**",
            f"- Catálogo FAIR: **{_yes_no(status.resources.metadata_catalog)}**",
            (
                "- Gobierno: "
                f"**{_yes_no(status.resources.governance_documentation)}**"
            ),
            "",
        ])

    if "lifecycle" in sections:
        lines.extend([
            "## Ciclo de Vida", "",
            f"- Migraciones: **{status.lifecycle.migrations}**",
            (
                "- Última migración: "
                f"{status.lifecycle.last_migrated_at or 'No registrada'}"
            ),
            (
                "- Última reparación: "
                f"{status.lifecycle.last_repaired_at or 'No registrada'}"
            ),
            "",
        ])

    if "history" in sections:
        lines.extend(["## Historial Reciente", ""])
        if report.history:
            lines.extend([
                "| Fecha | Evento | Salud |",
                "|---|---|---|",
                *[
                    (
                        f"| {event.occurred_at} | "
                        f"{event.event_type} | {event.health} |"
                    )
                    for event in report.history
                ],
            ])
        else:
            lines.append("_No se incluyeron eventos de historial._")
        lines.append("")

    if "recommendations" in sections:
        lines.extend(["## Recomendaciones", ""])
        if report.recommendations:
            lines.extend([
                (
                    f"- **{recommendation.priority.upper()} — "
                    f"{recommendation.code}:** {recommendation.message}"
                )
                for recommendation in report.recommendations
            ])
        else:
            lines.append("_No hay recomendaciones para este perfil._")
        lines.append("")

    return "\n".join(lines)


def report_to_html(report: ExecutiveReport) -> str:
    """Genera HTML autocontenido y seguro para lectura local."""
    markdown = report_to_markdown(report)
    blocks: list[str] = []
    in_table = False
    table_rows: list[list[str]] = []

    def flush_table() -> None:
        nonlocal in_table, table_rows
        if not table_rows:
            return
        header = table_rows[0]
        body = table_rows[2:] if len(table_rows) > 1 else []
        blocks.append("<table><thead><tr>" + "".join(
            f"<th>{_inline_markdown_to_html(cell)}</th>" for cell in header
        ) + "</tr></thead><tbody>")
        for row in body:
            blocks.append("<tr>" + "".join(
                f"<td>{_inline_markdown_to_html(cell)}</td>" for cell in row
            ) + "</tr>")
        blocks.append("</tbody></table>")
        table_rows = []
        in_table = False

    for raw in markdown.splitlines():
        line = raw.strip()
        if line.startswith("|") and line.endswith("|"):
            in_table = True
            table_rows.append([cell.strip() for cell in line.strip("|").split("|")])
            continue
        if in_table:
            flush_table()

        if line.startswith("# "):
            blocks.append(f"<h1>{_inline_markdown_to_html(line[2:])}</h1>")
        elif line.startswith("## "):
            blocks.append(f"<h2>{_inline_markdown_to_html(line[3:])}</h2>")
        elif line.startswith("- "):
            blocks.append(f"<p class='item'>{_inline_markdown_to_html(line[2:])}</p>")
        elif line.startswith("_") and line.endswith("_"):
            blocks.append(f"<p><em>{_inline_markdown_to_html(line.strip('_'))}</em></p>")
        elif line:
            blocks.append(f"<p>{_inline_markdown_to_html(line)}</p>")

    if in_table:
        flush_table()

    return """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1000px; margin: 2rem auto;
padding: 0 1rem; line-height: 1.5; }}
h1, h2 {{ border-bottom: 1px solid #ddd; padding-bottom: .35rem; }}
table {{ border-collapse: collapse; width: 100%; margin: 1rem 0; }}
th, td {{ border: 1px solid #ddd; padding: .55rem; text-align: left; }}
th {{ background: #f5f5f5; }}
.item {{ margin: .35rem 0; }}
</style>
</head>
<body>
{body}
</body>
</html>
""".format(
        title=escape(report.title),
        body="\n".join(blocks),
    )
