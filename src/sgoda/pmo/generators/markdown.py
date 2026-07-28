"""Generadores Markdown para las vistas del PMO."""

from __future__ import annotations

from sgoda.pmo.domain import ProjectModel


def status_label(value: str) -> str:
    return {
        "completed_verified": "Cerrado verificado",
        "completed_declared": "Cerrado declarado",
        "completed": "Cerrado",
        "in_progress": "En desarrollo",
        "planned": "Pendiente",
        "blocked": "Bloqueado",
        "cancelled": "Cancelado",
    }.get(value, value)


def dashboard_markdown(model: ProjectModel) -> str:
    lines = [
        "# Dashboard Ejecutivo SGODA-PUINAVE",
        "",
        f"**Estado general:** {status_label(model.project.status.value)}",
        f"**Hito actual:** {model.project.current_hito}",
        f"**Avance promedio documentado:** {model.average_progress} %",
        f"**Entregables cerrados:** {model.closed_deliverables} de {model.total_deliverables}",
        f"**Riesgos activos:** {model.active_risks}",
        "",
        "## Estado de entregables",
        "",
        "| Código | Entregable | Propósito administrativo | Estado | Avance |",
        "|---|---|---|---|---:|",
    ]
    for item in model.deliverables:
        lines.append(f"| {item.code} | {item.executive_name} | {item.purpose} | {status_label(item.status.value)} | {item.progress:.0f}% |")
    lines.extend(["", "## KPIs", "", "| KPI | Valor | Meta | Estado |", "|---|---:|---:|---|"])
    for kpi in model.kpis:
        lines.append(f"| {kpi.name} | {kpi.value:g} {kpi.unit} | {kpi.target:g} {kpi.unit} | {kpi.state.value} |")
    lines.extend(["", "## Riesgos prioritarios", "", "| Riesgo | Nivel | Mitigación |", "|---|---|---|"])
    for risk in model.risks:
        lines.append(f"| {risk.name} | {risk.level.value} | {risk.mitigation} |")
    return "\n".join(lines) + "\n"


def dmp_markdown(model: ProjectModel) -> str:
    lines = [
        "# Documento Maestro del Proyecto SGODA-PUINAVE — DMP v2.0",
        "",
        "## 1. Resumen ejecutivo",
        "",
        model.project.purpose,
        "",
        f"El proyecto cuenta con {model.total_deliverables} entregables principales gestionados por el PMO Digital. El avance promedio documentado es {model.average_progress} %.",
        "",
        "## 2. Catálogo ejecutivo de entregables",
        "",
    ]
    for item in model.deliverables:
        lines.extend([
            f"### {item.code} — {item.executive_name}",
            "",
            f"**Propósito:** {item.purpose}",
            "",
            f"**Beneficio:** {item.benefit}",
            "",
            f"**Estado:** {status_label(item.status.value)} · **Avance:** {item.progress:.0f}%",
            "",
            "**Productos principales:** " + ", ".join(item.products),
            "",
            f"**Evidencia:** {item.evidence}",
            "",
        ])
    lines.extend([
        "## 3. Riesgos y acciones",
        "",
        "| Riesgo | Nivel | Acción de mitigación |",
        "|---|---|---|",
    ])
    for risk in model.risks:
        lines.append(f"| {risk.name} | {risk.level.value} | {risk.mitigation} |")
    lines.extend([
        "",
        "## 4. Regla de actualización",
        "",
        "Todo cierre de SPB o DMP debe actualizar el modelo único del PMO y regenerar Dashboard, DMP, informe, presentación, catálogo y documento técnico.",
    ])
    return "\n".join(lines) + "\n"


def executive_report_markdown(model: ProjectModel) -> str:
    return f"""# Informe Ejecutivo para la Dirección — SPB-003.2

## Situación actual

SGODA-PUINAVE cuenta con una línea base documental y técnica versionada. El PMO Digital se implementa como plataforma de gobierno documental para centralizar la información del proyecto.

## Avance

- Avance promedio documentado: **{model.average_progress} %**.
- Entregables cerrados o declarados cerrados: **{model.closed_deliverables} de {model.total_deliverables}**.
- Último commit documental conocido: **{model.project.metadata.get('last_known_commit', '')}**.
- Última validación conocida: **{model.project.metadata.get('last_known_tests', '')}**.

## Decisión estratégica

SPB-003.2 convierte el DMP, el Dashboard, los informes, la presentación institucional y el documento técnico en vistas generadas desde una única fuente de información.

## Riesgos prioritarios

""" + "\n".join(f"- **{risk.name}:** {risk.mitigation}" for risk in model.risks) + "\n\n## Próximos pasos\n\n1. Integrar el paquete en el repositorio.\n2. Ejecutar pruebas.\n3. Publicar SPB-003.2 en GitHub.\n4. Mantener el modelo PMO como fuente de actualización permanente.\n"


def technical_document_markdown(model: ProjectModel) -> str:
    return f"""# Documento Técnico — Plataforma de Gobierno Documental PMO

## Objetivo

Implementar el PMO Digital como subsistema nativo de SGODA-PUINAVE para que Dashboard, DMP, informes, presentación institucional, catálogo ejecutivo y documento técnico se generen desde un modelo único.

## Arquitectura

Capas principales:

1. Modelo único del proyecto (`knowledge/project_model.json`).
2. Dominio PMO (`src/sgoda/pmo/domain`).
3. Repositorio JSON (`src/sgoda/pmo/repository`).
4. Gobierno y validación (`src/sgoda/pmo/governance`).
5. Generadores documentales (`src/sgoda/pmo/generators`).
6. Pipeline de publicación (`scripts/pmo/generate_governance_platform.py`).

## Flujo

Modelo del Proyecto → Validación → KPIs → Dashboard → DMP v2.0 → Informe Ejecutivo → Presentación Institucional → Catálogo → Documento Técnico.

## Criterios de aceptación

- Modelo único válido.
- Artefactos generados desde el mismo origen.
- Trazabilidad entre SPB, propósito, beneficio, estado, evidencias y documentos.
- Pruebas automatizadas del dominio, repositorio, validación y generadores.

## Estado inicial

El modelo incluye {model.total_deliverables} SPB principales, {len(model.risks)} riesgos y {len(model.kpis)} KPIs.
"""


def deliverable_catalog_markdown(model: ProjectModel) -> str:
    lines = ["# Catálogo Ejecutivo de Entregables", ""]
    for item in model.deliverables:
        lines.extend([
            f"## {item.code} — {item.executive_name}",
            "",
            f"**¿Qué es?** {item.name}.",
            "",
            f"**Propósito:** {item.purpose}",
            "",
            f"**Beneficio:** {item.benefit}",
            "",
            f"**Estado:** {status_label(item.status.value)} · **Avance:** {item.progress:.0f}%",
            "",
            "**Productos:** " + ", ".join(item.products),
            "",
        ])
    return "\n".join(lines) + "\n"
