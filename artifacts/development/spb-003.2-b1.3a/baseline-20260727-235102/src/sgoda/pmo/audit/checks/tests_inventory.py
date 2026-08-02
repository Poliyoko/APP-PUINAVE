from .base import AuditCheck
from ..models import Finding,Severity,Status

class TestsInventoryCheck(AuditCheck):
    code="AIR-TST"; category="TESTS"; name="Pruebas"

    def run(self,context):
        pmo=list((context.root/"tests").rglob("test_*.py")) if (context.root/"tests").exists() else []
        builder=list((context.root/"builder/tests").rglob("test_*.py")) if (context.root/"builder/tests").exists() else []
        nested=context.root/context.root.name
        duplicate=nested.exists()
        return [
          Finding("AIR-TST-001",self.category,"Pruebas PMO",Severity.HIGH,Status.PASS if pmo else Status.FAIL,str(len(pmo)),"Crear pruebas PMO."),
          Finding("AIR-TST-002",self.category,"Pruebas Builder separadas",Severity.MEDIUM,Status.PASS if builder else Status.WARN,str(len(builder)),"Ejecutarlas desde builder/."),
          Finding("AIR-TST-003",self.category,"Sin repositorio anidado",Severity.HIGH,Status.FAIL if duplicate else Status.PASS,str(nested) if duplicate else "No detectado","Mover o eliminar el clon anidado.")
        ],{"pmo_files":len(pmo),"builder_files":len(builder),"nested_repository":str(nested) if duplicate else None}