import json
from pathlib import Path


class JsonReporter:
    def write(self, result, path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(result.to_dict(), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return path


class MarkdownReporter:
    def write(self, result, path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        lines = [
            "# SGD-401 — Informe de Auditoría Integral del Repositorio",
            "",
            f"- **Proyecto:** {result.project}",
            f"- **Alcance:** {result.scope}",
            f"- **Rama:** `{result.branch}`",
            f"- **Commit:** `{result.commit}`",
            f"- **Cumplimiento:** {result.compliance_percentage} %",
            f"- **Hallazgos bloqueantes:** {sum(f.is_blocking() for f in result.findings)}",
            f"- **Dictamen:** **{result.verdict}**",
            "",
            "## Controles",
            "",
            "| Código | Categoría | Control | Severidad | Estado | Bloqueante | Evidencia | Recomendación |",
            "|---|---|---|---|---|---|---|---|",
        ]
        clean = lambda value: str(value).replace("|", "\\|").replace("\n", " ")
        for finding in result.findings:
            lines.append(
                f"| {clean(finding.code)} | {clean(finding.category)} | "
                f"{clean(finding.title)} | {finding.severity.value} | "
                f"{finding.status.value} | {'SÍ' if finding.is_blocking() else 'NO'} | "
                f"{clean(finding.evidence)} | {clean(finding.recommendation)} |"
            )
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path


class ClosureReporter:
    def write(self, result, path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        decision = {
            "APPROVED": "APTO PARA CIERRE",
            "APPROVED_WITH_ACTIONS": "CIERRE CONDICIONADO",
            "NOT_APPROVED": "NO APTO PARA CIERRE",
        }[result.verdict]
        path.write_text(
            "# ACT-003.2 — Acta Técnica de Decisión de Cierre\n\n"
            f"- **Commit:** `{result.commit}`\n"
            f"- **Cumplimiento:** {result.compliance_percentage} %\n"
            f"- **Hallazgos bloqueantes:** "
            f"{sum(f.is_blocking() for f in result.findings)}\n"
            f"- **Decisión:** **{decision}**\n\n"
            "La etiqueta y la Release solo se publican con dictamen `APPROVED`, "
            "árbol Git limpio y suites PMO/Builder aprobadas por separado.\n",
            encoding="utf-8",
        )
        return path
