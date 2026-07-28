from .base import AuditCheck
from ..models import Finding,Severity,Status

class TraceabilityCheck(AuditCheck):
    code="AIR-TRC"; category="TRACEABILITY"; name="Trazabilidad"
    required={
      "Código auditor":"src/sgoda/pmo/audit",
      "Pruebas auditor":"tests/pmo/audit",
      "Workflow":".github/workflows/spb-003-2-closure-audit.yml",
      "Documento arquitectura":"docs/05_Auditoria",
      "Expediente":"artifacts/audit/spb-003.2"
    }

    def run(self,context):
        findings=[]
        for name,relative in self.required.items():
            exists=(context.root/relative).exists()
            findings.append(Finding(f"AIR-TRC-{len(findings)+1:03d}",self.category,name,Severity.HIGH,Status.PASS if exists else Status.FAIL,relative,"" if exists else f"Incorporar {name}."))
        return findings,self.required