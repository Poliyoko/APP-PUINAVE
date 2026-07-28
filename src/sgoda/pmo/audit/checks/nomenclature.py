import re
from collections import Counter
from .base import AuditCheck
from ..models import Finding,Severity,Status

class NomenclatureCheck(AuditCheck):
    code="AIR-NOM"; category="NOMENCLATURE"; name="Nomenclatura"
    official={"SPB","SGD","ADR","ACT","CAT","EVD","TST","REL","BL","GUI","MAN","PRC","RDM","DGM","INF","DSH","ESP"}
    token=re.compile(r"\b([A-Z]{2,10})-(?=\d)")
    suffixes={".md",".txt",".py",".json",".yml",".yaml",".toml"}
    ignored={".git",".venv","venv","__pycache__","node_modules","artifacts"}

    def run(self,context):
        used=Counter()
        for p in context.root.rglob("*"):
            if not p.is_file() or p.suffix.lower() not in self.suffixes or any(x in self.ignored for x in p.parts): continue
            try: used.update(self.token.findall(p.read_text(encoding="utf-8",errors="ignore")))
            except OSError: pass
        unknown=sorted(set(used)-self.official)
        norms=list((context.root/"docs").rglob("*SGD-100*")) if (context.root/"docs").exists() else []
        return [
          Finding("AIR-NOM-001",self.category,"Norma SGD-100",Severity.HIGH,Status.PASS if norms else Status.FAIL,"; ".join(str(p.relative_to(context.root)) for p in norms) or "No encontrada","Crear o aprobar SGD-100."),
          Finding("AIR-NOM-002",self.category,"Prefijos no normalizados",Severity.MEDIUM,Status.PASS if not unknown else Status.WARN,", ".join(unknown) or "Ninguno","Revisar y actualizar SGD-100.")
        ],{"usage":dict(used),"unknown":unknown}