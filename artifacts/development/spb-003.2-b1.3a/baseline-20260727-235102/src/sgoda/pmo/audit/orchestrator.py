from .context import AuditContext
from .models import AuditResult
from .checks import DocumentationCheck,GitRepositoryCheck,NomenclatureCheck,StructureCheck,TestsInventoryCheck,TraceabilityCheck

class RepositoryAuditOrchestrator:
    def __init__(self,repository,checks=None):
        self.context=AuditContext.create(repository)
        self.checks=checks or [StructureCheck(),GitRepositoryCheck(),DocumentationCheck(),NomenclatureCheck(),TestsInventoryCheck(),TraceabilityCheck()]

    def run(self):
        result=AuditResult(repository=str(self.context.root))
        for check in self.checks:
            findings,data=check.run(self.context)
            result.findings.extend(findings)
            result.inventory[check.code]={"name":check.name,"category":check.category,"data":data}
        ok,result.branch=self.context.git("branch","--show-current")
        ok,result.commit=self.context.git("rev-parse","HEAD")
        return result.finalize()