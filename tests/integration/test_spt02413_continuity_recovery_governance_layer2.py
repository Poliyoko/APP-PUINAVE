from sgoda.integration.spt02413l2.service import ContinuityRecoveryGovernanceService
from sgoda.integration.spt02413l2.restore_testing import assess_restore_test
from sgoda.integration.spt02413l2.failover import assess_failover
from sgoda.integration.spt02413l2.integrity import canonical_sha256

def policy():
    return {
        "layer1_gate": "CONTINUITY_RESILIENCE_GATE_PASS",
        "recovery_strategy": {"documented": True, "prioritized": True, "dependencies_mapped": True, "runbook_defined": True, "owners_defined": True},
        "restore_testing": {"isolated_test": True, "integrity_verified": True, "evidence_required": True, "rollback_defined": True},
        "rto_rpo": {"rto_minutes": 60, "rpo_minutes": 15, "max_rto_minutes": 120, "max_rpo_minutes": 30},
        "redundancy": {"failure_domain_separation": True, "dependency_redundancy": True, "capacity_defined": True, "health_criteria_defined": True},
        "failover": {"approval_required": True, "prechecks_required": True, "rollback_required": True, "evidence_required": True, "manual_activation": True},
        "automatic_destructive_action": False, "secret_indirection": True,
    }

def test_gate_passes(): assert ContinuityRecoveryGovernanceService().assess(policy())["gate"]["passed"]
def test_twelve_controls(): assert len(ContinuityRecoveryGovernanceService().assess(policy())["controls"]) == 12
def test_no_failed_blockers(): assert ContinuityRecoveryGovernanceService().assess(policy())["gate"]["failed_blocking_controls"] == 0
def test_restore_is_non_destructive(): assert assess_restore_test(policy()["restore_testing"])["restore_executed"] is False
def test_restore_does_not_modify_production(): assert assess_restore_test(policy()["restore_testing"])["production_data_modified"] is False
def test_failover_not_executed(): assert assess_failover(policy()["failover"])["failover_executed"] is False
def test_traffic_not_shifted(): assert assess_failover(policy()["failover"])["traffic_shifted"] is False
def test_rto_is_within_limit(): assert ContinuityRecoveryGovernanceService().assess(policy())["objectives"]["valid"]
def test_redundancy_passes(): assert ContinuityRecoveryGovernanceService().assess(policy())["redundancy"]["valid"]
def test_recovery_strategy_passes(): assert ContinuityRecoveryGovernanceService().assess(policy())["strategy"]["valid"]
def test_sha256_is_stable(): assert canonical_sha256({"b":2,"a":1}) == canonical_sha256({"a":1,"b":2})
def test_secret_indirection_control(): assert ContinuityRecoveryGovernanceService().assess(policy())["controls"][-1].passed
