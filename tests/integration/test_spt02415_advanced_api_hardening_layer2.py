from sgoda.integration.spt02415l2 import AdvancedApiHardeningService
from sgoda.integration.spt02415l2.gate import AdvancedApiHardeningGate
def test_blocking_control_count(): assert len(AdvancedApiHardeningGate.BLOCKING)==15
def test_gate_passes(): assert AdvancedApiHardeningService().assess(10)["status"]=="ADVANCED_API_HARDENING_GATE_PASS"
def test_no_failed_controls(): assert AdvancedApiHardeningService().assess(10)["failed_blocking_controls"]==[]
def test_session_hardening(): assert AdvancedApiHardeningService().assess(1)["session_hardening"]["valid"]
def test_rate_limit_governance(): assert AdvancedApiHardeningService().assess(1)["rate_limit_governance"]["valid"]
def test_cors_csrf_governance(): assert AdvancedApiHardeningService().assess(1)["cors_csrf_governance"]["valid"]
def test_endpoint_security(): assert AdvancedApiHardeningService().assess(1)["endpoint_security"]["valid"]
def test_advanced_validation(): assert AdvancedApiHardeningService().assess(1)["advanced_validation"]["valid"]
def test_exposure_governance(): assert AdvancedApiHardeningService().assess(1)["exposure_governance"]["valid"]
def test_no_active_attack(): assert AdvancedApiHardeningService().assess(1)["active_attack_executed"] is False
def test_no_production_change(): assert AdvancedApiHardeningService().assess(1)["production_changed"] is False
def test_no_session_change(): assert AdvancedApiHardeningService().assess(1)["session_hardening"]["real_session_changed"] is False
def test_no_rate_limit_change(): assert AdvancedApiHardeningService().assess(1)["rate_limit_governance"]["rate_limit_changed"] is False
def test_no_endpoint_change(): assert AdvancedApiHardeningService().assess(1)["endpoint_security"]["endpoint_changed"] is False
def test_no_secret_exposure(): assert AdvancedApiHardeningService().assess(1)["secret_values_exposed"] is False
