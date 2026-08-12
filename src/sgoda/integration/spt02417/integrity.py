def assess_integrity_governance(p):
    checks={"sha256_required":bool(p.get("sha256_required")),"preservation_gate":bool(p.get("preservation_gate")),"evidence_manifest":bool(p.get("evidence_manifest")),"repository_sync_required":bool(p.get("repository_sync_required"))}
    return {"valid":all(checks.values()),**checks}
