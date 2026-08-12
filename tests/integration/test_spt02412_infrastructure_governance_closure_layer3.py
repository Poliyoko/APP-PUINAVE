from sgoda.integration.spt02412l3.service import InfrastructureClosureService
from sgoda.integration.spt02412l3.recertification import recertify
from sgoda.integration.spt02412l3.governance import governance_controls
from sgoda.integration.spt02412l3.gate import evaluate

L1 = "INFRASTRUCTURE_SECURITY_GATE_PASS"
L2 = "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"


def test_recertification_has_five_domains():
    assert len(recertify()) == 5


def test_recertification_all_pass():
    assert all(x.decision == "RECERTIFIED" for x in recertify())


def test_governance_has_fourteen_blocking_controls():
    assert len(governance_controls(L1, L2, recertify())) == 14


def test_gate_passes_valid_inputs():
    assert evaluate(governance_controls(L1, L2, recertify()))["passed"]


def test_bad_layer1_blocks_closure():
    result = InfrastructureClosureService().close("BAD", L2)
    assert result["status"] == "CLOSURE_HOLD"


def test_bad_layer2_blocks_closure():
    result = InfrastructureClosureService().close(L1, "BAD")
    assert result["status"] == "CLOSURE_HOLD"


def test_valid_inputs_close_institutionally():
    result = InfrastructureClosureService().close(L1, L2)
    assert result["status"] == "INSTITUTIONALLY_CLOSED"


def test_no_failed_controls_on_valid_closure():
    result = InfrastructureClosureService().close(L1, L2)
    assert result["failed_controls"] == []


def test_evidence_count_preserved():
    result = InfrastructureClosureService().close(L1, L2, 14)
    assert result["evidence_records"] == 14


def test_exposure_governance_passes():
    assert governance_controls(L1, L2, recertify())["exposure_governance"]


def test_change_governance_passes():
    assert governance_controls(L1, L2, recertify())["infrastructure_change_governance"]


def test_no_real_change_control_passes():
    assert governance_controls(L1, L2, recertify())["no_real_infrastructure_change"]


def test_no_service_action_control_passes():
    assert governance_controls(L1, L2, recertify())["no_service_action"]


def test_no_network_action_control_passes():
    assert governance_controls(L1, L2, recertify())["no_network_action"]
