from sgoda.integration.spt02415l3 import FinalApplicationApiGovernanceService
from sgoda.integration.spt02415l3.recertification import build_recertification
from sgoda.integration.spt02415l3.governance import final_controls

L1="APPLICATION_API_SECURITY_GATE_PASS"
L2="ADVANCED_API_HARDENING_GATE_PASS"

def test_twelve_recertifications(): assert len(build_recertification()) == 12
def test_all_recertified(): assert all(r.decision=="RECERTIFIED" for r in build_recertification())
def test_twenty_two_controls(): assert len(final_controls(L1,L2,build_recertification())) == 22
def test_institutional_closure_passes(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["status"]=="INSTITUTIONALLY_CLOSED"
def test_invalid_layer1_holds(): assert FinalApplicationApiGovernanceService().assess("BAD",L2)["status"]=="CLOSURE_HOLD"
def test_invalid_layer2_holds(): assert FinalApplicationApiGovernanceService().assess(L1,"BAD")["status"]=="CLOSURE_HOLD"
def test_no_failed_controls(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["failed_blocking_controls"]==[]
def test_owasp_recertification(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["owasp_recertification"]
def test_endpoint_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["endpoint_security_governance"]
def test_session_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["session_security_governance"]
def test_exposure_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["api_exposure_governance"]
def test_rate_limit_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["rate_limit_governance"]
def test_cors_csrf_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["cors_csrf_governance"]
def test_no_active_attack(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["active_attack_executed"] is False
def test_no_session_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["real_session_changed"] is False
def test_no_rate_limit_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["rate_limit_changed"] is False
def test_no_endpoint_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["endpoint_changed"] is False
def test_no_exposure_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["exposure_changed"] is False
def test_no_production_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["production_changed"] is False
def test_no_external_connection(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["external_connection_opened"] is False
def test_no_secret_exposure(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["secret_values_exposed"] is False
def test_blocking_control_count(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["blocking_controls"] == 22
