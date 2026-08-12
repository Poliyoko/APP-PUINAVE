from sgoda.integration.spt02411l3.service import DataPrivacyClosureService
from sgoda.integration.spt02411l3.recertification import recertify
from sgoda.integration.spt02411l3.governance import governance_controls
from sgoda.integration.spt02411l3.gate import evaluate

L1="DATA_PRIVACY_GOVERNANCE_GATE_PASS"
L2="DATA_LIFECYCLE_GOVERNANCE_GATE_PASS"

def test_recertification_has_four_domains():
    assert len(recertify()) == 4

def test_recertification_all_pass():
    assert all(x.decision == "RECERTIFIED" for x in recertify())

def test_governance_has_twelve_blocking_controls():
    assert len(governance_controls(L1,L2,recertify())) == 12

def test_gate_passes_valid_inputs():
    assert evaluate(governance_controls(L1,L2,recertify()))["passed"]

def test_bad_layer1_blocks_closure():
    r=DataPrivacyClosureService().close("BAD",L2)
    assert r["status"] == "CLOSURE_HOLD"

def test_bad_layer2_blocks_closure():
    r=DataPrivacyClosureService().close(L1,"BAD")
    assert r["status"] == "CLOSURE_HOLD"

def test_valid_inputs_close_institutionally():
    r=DataPrivacyClosureService().close(L1,L2)
    assert r["status"] == "INSTITUTIONALLY_CLOSED"

def test_no_failed_controls_on_valid_closure():
    assert DataPrivacyClosureService().close(L1,L2)["failed_controls"] == []

def test_evidence_count_preserved():
    assert DataPrivacyClosureService().close(L1,L2,12)["evidence_records"] == 12

def test_classification_governance_pass():
    assert governance_controls(L1,L2,recertify())["classification_governance"]

def test_legal_hold_governance_pass():
    assert governance_controls(L1,L2,recertify())["legal_hold_governance"]

def test_no_destructive_action_is_blocking_control():
    assert governance_controls(L1,L2,recertify())["no_destructive_action"]