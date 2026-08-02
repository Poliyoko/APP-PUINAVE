from .base import AuditCheck
from ..models import Finding,Severity,Status

class DocumentationCheck(AuditCheck):
    code="AIR-DOC"; category="DOCUMENTATION"; name="DocumentaciÃ³n"
    documents={"DMP":"*DMP*","SGD-100":"*SGD-100*","Dashboard":"*Dashboard*","Informe Ejecutivo":"*Informe*Ejecutivo*"}

    def run(self,context):
        roots=[p for p in (context.root/"docs",context.root/"artifacts") if p.exists()]
        findings=[]; inventory={}
        for name,pattern in self.documents.items():
            matches=sorted({str(p.relative_to(context.root)) for root in roots for p in root.rglob(pattern) if p.is_file()})
            mandatory=name in {"DMP","SGD-100"}
            inventory[name]=matches
            findings.append(Finding(
              f"AIR-DOC-{len(findings)+1:03d}",self.category,f"Documento: {name}",
              Severity.HIGH if mandatory else Severity.MEDIUM,
              Status.PASS if matches else (Status.FAIL if mandatory else Status.WARN),
              "; ".join(matches) or "No encontrado","" if matches else f"Generar o ubicar {name}."
            ))
        return findings,inventory