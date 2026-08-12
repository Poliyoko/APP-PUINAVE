def assess_network_security(p):
    checks={"network_surface_inventory":bool(p.get("network_surface_inventory")),"trust_boundary_governance":bool(p.get("trust_boundary_governance")),"segmentation_governance":bool(p.get("segmentation_governance")),"dns_governance":bool(p.get("dns_governance")),"proxy_governance":bool(p.get("proxy_governance")),"egress_governance":bool(p.get("egress_governance"))}
    return {"valid":all(checks.values()),**checks,"network_configuration_changed":False}
