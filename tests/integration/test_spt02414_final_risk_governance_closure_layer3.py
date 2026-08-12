from sgoda.integration.spt02414l3.service import FinalRiskGovernanceService
from sgoda.integration.spt02414l3.recertification import build_recertification
from sgoda.integration.spt02414l3.governance import final_controls

L1="SECURITY_RISK_GOVERNANCE_GATE_PASS"
L2="RISK_REGISTER_GOVERNANCE_GATE_PASS"

def test_nine_recertifications(): assert len(build_recertification()) == 9
def test_all_recertified(): assert all(r.decision=="RECERTIFIED" for r in build_recertification())
def test_seventeen_controls(): assert len(final_controls(L1,L2,build_recertification())) == 17
def test_institutional_closure_passes(): assert FinalRiskGovernanceService().assess(L1,L2)["status"]=="INSTITUTIONALLY_CLOSED"
def test_invalid_layer1_holds(): assert FinalRiskGovernanceService().assess("BAD",L2)["status"]=="CLOSURE_HOLD"
def test_invalid_layer2_holds(): assert FinalRiskGovernanceService().assess(L1,"BAD")["status"]=="CLOSURE_HOLD"
def test_no_failed_controls(): assert FinalRiskGovernanceService().assess(L1,L2)["failed_blocking_controls"]==[]
def test_master_register_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["master_risk_register"]
def test_residual_risk_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["residual_risk_governance"]
def test_exception_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["risk_exception_governance"]
def test_acceptance_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["risk_acceptance_governance"]
def test_no_automatic_acceptance(): assert FinalRiskGovernanceService().assess(L1,L2)["automatic_acceptance"] is False
def test_no_treatment_execution(): assert FinalRiskGovernanceService().assess(L1,L2)["treatment_executed"] is False
def test_no_production_change(): assert FinalRiskGovernanceService().assess(L1,L2)["production_changed"] is False
def test_no_external_connection(): assert FinalRiskGovernanceService().assess(L1,L2)["external_connection_opened"] is False
def test_no_secret_exposure(): assert FinalRiskGovernanceService().assess(L1,L2)["secret_values_exposed"] is False
def test_blocking_control_count(): assert FinalRiskGovernanceService().assess(L1,L2)["blocking_controls"] == 17
