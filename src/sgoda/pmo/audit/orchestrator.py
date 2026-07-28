from .context import AuditContext
from .models import AuditResult
from .checks import (
    DocumentationCheck,
    GitRepositoryCheck,
    NomenclatureCheck,
    RepositoryQualityCheck,
    StructureCheck,
    TestsInventoryCheck,
    TraceabilityCheck,
)


class RepositoryAuditOrchestrator:
    def __init__(self, repository, checks=None):
        self.context = AuditContext.create(repository)
        self.checks = checks or [
            StructureCheck(),
            GitRepositoryCheck(),
            DocumentationCheck(),
            NomenclatureCheck(),
            TestsInventoryCheck(),
            TraceabilityCheck(),
            RepositoryQualityCheck(),
        ]

    def run(self):
        result = AuditResult(repository=str(self.context.root))
        for check in self.checks:
            findings, data = check.run(self.context)
            result.findings.extend(findings)
            result.inventory[check.code] = {
                "name": check.name,
                "category": check.category,
                "data": data,
            }

        ok, branch = self.context.git("branch", "--show-current")
        result.branch = branch if ok else ""
        ok, commit = self.context.git("rev-parse", "HEAD")
        result.commit = commit if ok else ""
        return result.finalize()
