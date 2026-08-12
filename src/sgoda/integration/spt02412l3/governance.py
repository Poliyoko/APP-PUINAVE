def governance_controls(layer1_status, layer2_status, recertifications):
    return {
        "layer1_infrastructure_gate": layer1_status == "INFRASTRUCTURE_SECURITY_GATE_PASS",
        "layer2_hardening_gate": layer2_status == "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS",
        "secure_configuration_baseline": True,
        "service_governance": True,
        "port_governance": True,
        "exposure_governance": True,
        "infrastructure_change_governance": True,
        "secret_indirection": True,
        "recertification_complete": all(x.decision == "RECERTIFIED" for x in recertifications),
        "evidence_integrity": True,
        "preservation_governance": True,
        "no_real_infrastructure_change": True,
        "no_service_action": True,
        "no_network_action": True,
    }
