"""Serializadores Markdown y JSON para reportes ejecutivos."""

from __future__ import annotations

import json

from .report_models import ExecutiveReport


def _yes_no(value: bool) -> str:
    return "OK" if value else "FALTANTE"


def report_to_json(report: ExecutiveReport) -> str:
    """Serializa un reporte ejecutivo a JSON UTF-8."""
    return json.dumps(
        report.to_dict(),
        ensure_ascii=False,
        indent=2,
    )


def report_to_markdown(report: ExecutiveReport) -> str:
    """Serializa un reporte ejecutivo a Markdown estable."""
    status = report.status
    lines = [
        f"# {report.title}",
        "",
        "## Resumen Ejecutivo",
        "",
        f"- **Proyecto:** {status.project.name}",
        f"- **Ruta:** `{status.workspace}`",
        f"- **Builder:** {status.builder_version}",
        f"- **Esquema:** {status.project.schema_version}",
        f"- **Estado general:** **{status.health}**",
        f"- **Puntuación:** **{status.audit.score}/100**",
        f"- **Generado:** {report.generated_at}",
        "",
        "## Auditoría y Calidad",
        "",
        "| Indicador | Valor |",
        "|---|---:|",
        f"| Estado | {status.audit.status} |",
        f"| Errores | {status.audit.errors} |",
        f"| Advertencias | {status.audit.warnings} |",
        f"| Información | {status.audit.information} |",
        f"| Controles aprobados | {status.audit.successes} |",
        "",
        "## Componentes",
        "",
    ]

    if status.components:
        lines.extend(
            [
                "| Tipo | Total |",
                "|---|---:|",
                *[
                    f"| {kind} | {total} |"
                    for kind, total in sorted(status.components.items())
                ],
            ]
        )
    else:
        lines.append("_No hay componentes registrados._")

    lines.extend(
        [
            "",
            "## Extensiones",
            "",
            f"- Plugins: **{status.extensions.plugins}**",
            f"- Plantillas: **{status.extensions.templates}**",
            f"- Extensiones habilitadas: **{status.extensions.enabled}**",
            "",
            "## Recursos",
            "",
            f"- Léxico: **{_yes_no(status.resources.lexicon)}**",
            (
                "- Catálogo FAIR: "
                f"**{_yes_no(status.resources.metadata_catalog)}**"
            ),
            (
                "- Gobierno: "
                f"**{_yes_no(status.resources.governance_documentation)}**"
            ),
            "",
            "## Ciclo de Vida",
            "",
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
            "## Historial Reciente",
            "",
        ]
    )

    if report.history:
        lines.extend(
            [
                "| Fecha | Evento | Salud |",
                "|---|---|---|",
                *[
                    (
                        f"| {event.occurred_at} | "
                        f"{event.event_type} | {event.health} |"
                    )
                    for event in report.history
                ],
            ]
        )
    else:
        lines.append("_No se incluyeron eventos de historial._")

    lines.extend(
        [
            "",
            "## Recomendaciones",
            "",
            *[
                (
                    f"- **{recommendation.priority.upper()} — "
                    f"{recommendation.code}:** {recommendation.message}"
                )
                for recommendation in report.recommendations
            ],
            "",
        ]
    )
    return "\n".join(lines)
