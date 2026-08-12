def assess_configuration_governance(p):
    checks={"configuration_as_code":bool(p.get("configuration_as_code")),"version_controlled_configuration":bool(p.get("version_controlled_configuration")),"change_review":bool(p.get("change_review")),"drift_detection_governance":bool(p.get("drift_detection_governance")),"rollback_governance":bool(p.get("rollback_governance")),"evidence_required":bool(p.get("evidence_required"))}
    return {"valid":all(checks.values()),**checks,"configuration_changed":False}
