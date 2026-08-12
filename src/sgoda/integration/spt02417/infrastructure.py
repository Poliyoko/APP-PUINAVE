def assess_infrastructure_inventory(p):
    checks={"asset_inventory":bool(p.get("asset_inventory")),"environment_classification":bool(p.get("environment_classification")),"ownership_governance":bool(p.get("ownership_governance")),"configuration_source_traceability":bool(p.get("configuration_source_traceability")),"exposure_inventory":bool(p.get("exposure_inventory"))}
    return {"valid":all(checks.values()),**checks}
