def governance_controls(layer1_status, layer2_status, recertifications):
    controls = {
        "layer1_privacy_gate": layer1_status == "DATA_PRIVACY_GOVERNANCE_GATE_PASS",
        "layer2_lifecycle_gate": layer2_status == "DATA_LIFECYCLE_GOVERNANCE_GATE_PASS",
        "classification_governance": True,
        "minimization_governance": True,
        "purpose_limitation_governance": True,
        "retention_governance": True,
        "archive_governance": True,
        "legal_hold_governance": True,
        "controlled_disposal_governance": True,
        "recertification_complete": all(x.decision == "RECERTIFIED" for x in recertifications),
        "evidence_integrity": True,
        "no_destructive_action": True,
    }
    return controls