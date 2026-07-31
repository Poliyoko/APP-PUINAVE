from __future__ import annotations
from typing import Any

def audit_retention(records) -> dict[str,Any]:
    findings=[]
    for record in records:
        if not record.retention_policy:
            findings.append({"evidence_id":record.evidence_id,"severity":"warning","code":"RET-POLICY-MISSING"})
        if record.retention_action=="delete-candidate" and not record.retention_evaluated_at_utc:
            findings.append({"evidence_id":record.evidence_id,"severity":"error","code":"RET-EVALUATION-MISSING"})
        if record.legal_hold and record.retention_action not in ("","keep"):
            findings.append({"evidence_id":record.evidence_id,"severity":"error","code":"RET-LEGAL-HOLD-CONFLICT"})
    return {
        "schema":"sgoda.sems.retention-audit/v1",
        "records":len(records),
        "findings":findings,
        "compliant":not any(item["severity"]=="error" for item in findings),
    }