def assess_port_security(p):
    checks={"port_inventory":bool(p.get("port_inventory")),"minimum_exposure_principle":bool(p.get("minimum_exposure_principle")),"admin_port_governance":bool(p.get("admin_port_governance")),"loopback_binding_review":bool(p.get("loopback_binding_review")),"public_binding_review":bool(p.get("public_binding_review")),"firewall_policy_reference":bool(p.get("firewall_policy_reference"))}
    return {"valid":all(checks.values()),**checks,"real_port_changed":False,"firewall_changed":False,"active_network_scan_executed":False}
