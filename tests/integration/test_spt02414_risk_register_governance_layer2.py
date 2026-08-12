from sgoda.integration.spt02414l2.service import RiskRegisterGovernanceService
from sgoda.integration.spt02414l2.register import build_master_register
from sgoda.integration.spt02414l2.prioritization import prioritize
from sgoda.integration.spt02414l2.residual import residual_risk
from sgoda.integration.spt02414l2.acceptance import acceptance_governance
from sgoda.integration.spt02414l2.integrity import canonical_sha256

L1="SECURITY_RISK_GOVERNANCE_GATE_PASS"

def test_master_register_has_records(): assert len(build_master_register()) >= 4
def test_prioritization_puts_critical_first(): assert prioritize(build_master_register())[0].priority == "CRITICAL"
def test_gate_passes(): assert RiskRegisterGovernanceService().assess(L1)["status"] == "RISK_REGISTER_GOVERNANCE_GATE_PASS"
def test_twelve_blocking_controls(): assert len(RiskRegisterGovernanceService().assess(L1)["gate"]["controls"]) == 12
def test_no_failed_controls(): assert RiskRegisterGovernanceService().assess(L1)["gate"]["failed"] == []
def test_residual_not_greater_than_inherent():
    for r in build_master_register(): assert residual_risk(r)["residual_score"] <= residual_risk(r)["inherent_score"]
def test_exception_requires_acceptance_governance():
    flagged=[r for r in build_master_register() if r.exception]
    assert flagged and all(acceptance_governance(r)["required"] for r in flagged)
def test_no_automatic_acceptance(): assert all(not x["accepted_automatically"] for x in RiskRegisterGovernanceService().assess(L1)["acceptances"])
def test_treatment_not_executed(): assert RiskRegisterGovernanceService().assess(L1)["treatment_executed"] is False
def test_no_production_change(): assert RiskRegisterGovernanceService().assess(L1)["production_changed"] is False
def test_no_secret_exposure(): assert RiskRegisterGovernanceService().assess(L1)["secret_values_exposed"] is False
def test_integrity_stable(): assert canonical_sha256({"b":2,"a":1}) == canonical_sha256({"a":1,"b":2})
