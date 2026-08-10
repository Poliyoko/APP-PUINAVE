from __future__ import annotations

import json
from pathlib import Path

from .auditor import IntelligentAuditor
from .models import AuditReport
from .rules import AuditPolicy


class Spt0237Layer1Service:
    def __init__(self, root: str | Path, policy: AuditPolicy | None = None):
        self.root = Path(root)
        self.policy = policy or AuditPolicy.default()

    def audit(self) -> AuditReport:
        return IntelligentAuditor(self.root, self.policy).run()

    def audit_to_json(self, destination: str | Path) -> AuditReport:
        report = self.audit()
        path = Path(destination)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(report.to_dict(), ensure_ascii=False, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        return report
