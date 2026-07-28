"""Generador HTML del Dashboard Ejecutivo."""

from __future__ import annotations

from html import escape
from sgoda.pmo.domain import ProjectModel
from sgoda.pmo.generators.markdown import status_label


def dashboard_html(model: ProjectModel) -> str:
    cards = "".join([
        f"<div class='card'><span>Avance</span><strong>{model.average_progress}%</strong></div>",
        f"<div class='card'><span>SPB cerrados</span><strong>{model.closed_deliverables}/{model.total_deliverables}</strong></div>",
        f"<div class='card'><span>Riesgos</span><strong>{model.active_risks}</strong></div>",
        f"<div class='card'><span>Pruebas conocidas</span><strong>{escape(model.project.metadata.get('last_known_tests', ''))}</strong></div>",
    ])
    rows = "".join(
        f"<tr><td>{escape(item.code)}</td><td>{escape(item.executive_name)}</td><td>{escape(item.purpose)}</td><td>{escape(status_label(item.status.value))}</td><td>{item.progress:.0f}%</td></tr>"
        for item in model.deliverables
    )
    risks = "".join(f"<li><strong>{escape(risk.name)}</strong>: {escape(risk.mitigation)}</li>" for risk in model.risks)
    return f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Dashboard Ejecutivo SGODA-PUINAVE</title>
<style>
body {{ font-family: Arial, sans-serif; margin: 28px; color: #1f2937; background: #f8fafc; }}
h1 {{ color: #12355b; }}
.grid {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin: 24px 0; }}
.card {{ background: white; border-radius: 14px; padding: 18px; box-shadow: 0 2px 8px #ccd; }}
.card span {{ display: block; color: #64748b; font-size: 13px; }}
.card strong {{ font-size: 28px; color: #0f766e; }}
table {{ width: 100%; border-collapse: collapse; background: white; }}
th, td {{ border: 1px solid #e2e8f0; padding: 10px; vertical-align: top; }}
th {{ background: #dbeafe; text-align: left; }}
.section {{ background: white; padding: 18px; border-radius: 14px; margin-top: 22px; }}
</style>
</head>
<body>
<h1>Dashboard Ejecutivo SGODA-PUINAVE</h1>
<p><strong>Hito actual:</strong> {escape(model.project.current_hito)}</p>
<div class="grid">{cards}</div>
<div class="section"><h2>Estado de entregables</h2><table><thead><tr><th>Código</th><th>Nombre ejecutivo</th><th>Propósito</th><th>Estado</th><th>Avance</th></tr></thead><tbody>{rows}</tbody></table></div>
<div class="section"><h2>Riesgos prioritarios</h2><ul>{risks}</ul></div>
</body>
</html>"""
