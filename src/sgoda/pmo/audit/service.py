from pathlib import Path
from .orchestrator import RepositoryAuditOrchestrator
from .reporting import ClosureReporter,JsonReporter,MarkdownReporter

class RepositoryAuditService:
    def execute(self,repository,output):
        result=RepositoryAuditOrchestrator(repository).run()
        out=Path(output)
        return {
          "result":result,
          "markdown":MarkdownReporter().write(result,out/"SGD-401-informe-auditoria-integral.md"),
          "json":JsonReporter().write(result,out/"SGD-401-informe-auditoria-integral.json"),
          "act":ClosureReporter().write(result,out/"ACT-003.2-acta-tecnica-cierre.md")
        }