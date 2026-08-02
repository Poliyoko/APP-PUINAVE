import json
from pathlib import Path

class JsonReporter:
    def write(self,result,path):
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(result.to_dict(),ensure_ascii=False,indent=2),encoding="utf-8")
        return path

class MarkdownReporter:
    def write(self,result,path):
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
        lines=[
          "# SGD-401 â€” Informe de AuditorÃ­a Integral del Repositorio","",
          f"- **Proyecto:** {result.project}",f"- **Alcance:** {result.scope}",
          f"- **Rama:** `{result.branch}`",f"- **Commit:** `{result.commit}`",
          f"- **Cumplimiento:** {result.compliance_percentage} %",
          f"- **Dictamen:** **{result.verdict}**","","## Controles","",
          "| CÃ³digo | CategorÃ­a | Control | Severidad | Estado | Evidencia | RecomendaciÃ³n |",
          "|---|---|---|---|---|---|---|"
        ]
        clean=lambda x:str(x).replace("|","\\|").replace("\n"," ")
        for f in result.findings:
            lines.append(f"| {clean(f.code)} | {clean(f.category)} | {clean(f.title)} | {f.severity.value} | {f.status.value} | {clean(f.evidence)} | {clean(f.recommendation)} |")
        path.write_text("\n".join(lines)+"\n",encoding="utf-8")
        return path

class ClosureReporter:
    def write(self,result,path):
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
        decision={"APPROVED":"APTO PARA CIERRE","APPROVED_WITH_ACTIONS":"CIERRE CONDICIONADO","NOT_APPROVED":"NO APTO PARA CIERRE"}[result.verdict]
        path.write_text(
          f"# ACT-003.2 â€” Acta TÃ©cnica de DecisiÃ³n de Cierre\n\n"
          f"- **Commit:** `{result.commit}`\n- **Cumplimiento:** {result.compliance_percentage} %\n"
          f"- **DecisiÃ³n:** **{decision}**\n\n"
          "La etiqueta y la Release solo se publican con dictamen `APPROVED`, Ã¡rbol Git limpio y suites PMO/Builder aprobadas por separado.\n",
          encoding="utf-8"
        )
        return path