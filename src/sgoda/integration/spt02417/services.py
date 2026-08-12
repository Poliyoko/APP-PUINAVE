def assess_service_security(p):
    checks={"service_inventory":bool(p.get("service_inventory")),"minimum_service_principle":bool(p.get("minimum_service_principle")),"startup_governance":bool(p.get("startup_governance")),"service_identity_review":bool(p.get("service_identity_review")),"dependency_governance":bool(p.get("dependency_governance")),"failure_behavior_review":bool(p.get("failure_behavior_review"))}
    return {"valid":all(checks.values()),**checks,"real_service_changed":False}
