from .base import AuditCheck
from ..models import Finding,Severity,Status

class StructureCheck(AuditCheck):
    code="AIR-STR"; category="STRUCTURE"; name="Estructura institucional"
    required=(".github","docs","knowledge","scripts","src","tests","README.md")

    def run(self,context):
        findings=[]; missing=[]
        for item in self.required:
            exists=(context.root/item).exists()
            if not exists: missing.append(item)
            findings.append(Finding(
                f"{self.code}-{len(findings)+1:03d}",self.category,f"Elemento requerido: {item}",
                Severity.HIGH if item in {"src","tests","README.md"} else Severity.MEDIUM,
                Status.PASS if exists else Status.FAIL,str(context.root/item),
                "" if exists else f"Crear, restaurar o justificar {item}."
            ))
        return findings,{"missing":missing}