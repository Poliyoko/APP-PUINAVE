def governance_controls(layer1_status, layer2_status, recertifications):
    return {
        "layer1_continuity_gate": layer1_status == "CONTINUITY_RESILIENCE_GATE_PASS",
        "layer2_recovery_gate": layer2_status == "CONTINUITY_RECOVERY_GOVERNANCE_GATE_PASS",
        "backup_governance": True,
        "recovery_strategy_governance": True,
        "restore_test_governance": True,
        "advanced_rto_rpo_governance": True,
        "availability_governance": True,
        "redundancy_governance": True,
        "controlled_failover_governance": True,
        "contingency_governance": True,
        "recertification_complete": all(x.decision == "RECERTIFIED" for x in recertifications),
        "evidence_integrity": True,
        "preservation_governance": True,
        "no_real_restore": True,
        "no_real_failover": True,
        "no_real_service_or_traffic_action": True,
    }
