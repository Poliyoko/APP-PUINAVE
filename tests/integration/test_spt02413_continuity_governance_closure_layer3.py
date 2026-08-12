from sgoda.integration.spt02413l3.service import ContinuityClosureService
from sgoda.integration.spt02413l3.recertification import recertify
from sgoda.integration.spt02413l3.governance import governance_controls
from sgoda.integration.spt02413l3.gate import evaluate

L1 = "CONTINUITY_RESILIENCE_GATE_PASS"
L2 = "CONTINUITY_RECOVERY_GOVERNANCE_GATE_PASS"

def test_recertification_has_seven_domains():
    assert len(recertify()) == 7

def test_all_recertifications_pass():
    assert all(x.decision == "RECERTIFIED" for x in recertify())

def test_governance_has_sixteen_blocking_controls():
    assert len(governance_controls(L1, L2, recertify())) == 16

def test_gate_passes_valid_inputs():
    assert evaluate(governance_controls(L1, L2, recertify()))["passed"]

def test_invalid_layer1_holds():
    assert ContinuityClosureService().close("BAD", L2)["status"] == "CLOSURE_HOLD"

def test_invalid_layer2_holds():
    assert ContinuityClosureService().close(L1, "BAD")["status"] == "CLOSURE_HOLD"

def test_valid_inputs_close_institutionally():
    assert ContinuityClosureService().close(L1, L2)["status"] == "INSTITUTIONALLY_CLOSED"

def test_no_failed_controls():
    assert ContinuityClosureService().close(L1, L2)["failed_controls"] == []

def test_evidence_count():
    assert ContinuityClosureService().close(L1, L2, 16)["evidence_records"] == 16

def test_backup_governance_passes():
    assert governance_controls(L1, L2, recertify())["backup_governance"]

def test_recovery_strategy_passes():
    assert governance_controls(L1, L2, recertify())["recovery_strategy_governance"]

def test_restore_test_governance_passes():
    assert governance_controls(L1, L2, recertify())["restore_test_governance"]

def test_rto_rpo_governance_passes():
    assert governance_controls(L1, L2, recertify())["advanced_rto_rpo_governance"]

def test_redundancy_governance_passes():
    assert governance_controls(L1, L2, recertify())["redundancy_governance"]

def test_failover_governance_passes():
    assert governance_controls(L1, L2, recertify())["controlled_failover_governance"]

def test_no_real_actions():
    controls = governance_controls(L1, L2, recertify())
    assert controls["no_real_restore"]
    assert controls["no_real_failover"]
    assert controls["no_real_service_or_traffic_action"]
