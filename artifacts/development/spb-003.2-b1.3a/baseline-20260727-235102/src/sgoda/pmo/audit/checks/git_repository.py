from .base import AuditCheck
from ..models import Finding,Severity,Status

class GitRepositoryCheck(AuditCheck):
    code="AIR-GIT"; category="GIT"; name="Gobierno Git"
    tags={"spb-003.2","spb-003.2-baseline-v1.0","v0.3.2","v1.0.0-spb0032"}

    def run(self,context):
        findings=[]; inventory={}
        ok,value=context.git("rev-parse","--is-inside-work-tree")
        valid=ok and value.lower()=="true"
        findings.append(Finding("AIR-GIT-001",self.category,"Repositorio Git vÃ¡lido",Severity.CRITICAL,Status.PASS if valid else Status.FAIL,value,"Ejecutar desde la raÃ­z oficial."))
        if not valid: return findings,inventory
        _,branch=context.git("branch","--show-current")
        _,commit=context.git("rev-parse","HEAD")
        _,dirty=context.git("status","--porcelain")
        _,remote=context.git("remote","-v")
        _,tags=context.git("tag","--list")
        tag_list=[x for x in tags.splitlines() if x]
        inventory={"branch":branch,"commit":commit,"dirty":dirty.splitlines(),"remotes":remote.splitlines(),"tags":tag_list}
        findings += [
          Finding("AIR-GIT-002",self.category,"Ãrbol Git limpio",Severity.HIGH,Status.PASS if not dirty else Status.FAIL,dirty or "Limpio","Confirmar o descartar cambios."),
          Finding("AIR-GIT-003",self.category,"Remoto oficial configurado",Severity.HIGH,Status.PASS if remote else Status.FAIL,remote,"Configurar GitHub."),
          Finding("AIR-GIT-004",self.category,"Tag de cierre",Severity.MEDIUM,Status.PASS if any(t.lower() in self.tags for t in tag_list) else Status.WARN,", ".join(tag_list) or "Sin tag","Crear el tag solo despuÃ©s del dictamen APPROVED.")
        ]
        return findings,inventory