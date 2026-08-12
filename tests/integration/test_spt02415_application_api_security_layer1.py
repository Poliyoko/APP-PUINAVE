from sgoda.integration.spt02415 import ApplicationApiSecurityService
from sgoda.integration.spt02415.gate import ApplicationApiSecurityGate
from sgoda.integration.spt02415.input_validation import assess_input_validation
from sgoda.integration.spt02415.session import assess_session_security
from sgoda.integration.spt02415.api import assess_api_security
from sgoda.integration.spt02415.owasp import assess_owasp_control_coverage

def test_gate_has_thirteen_controls(): assert len(ApplicationApiSecurityGate.BLOCKING)==13
def test_full_gate_passes(): assert ApplicationApiSecurityService().assess(10)["status"]=="APPLICATION_API_SECURITY_GATE_PASS"
def test_no_failed_controls(): assert ApplicationApiSecurityService().assess(10)["failed_blocking_controls"]==[]
def test_input_validation_requires_all_controls():
    r=assess_input_validation({"allowlist_or_schema_validation":True,"size_limits":True,"type_validation":True,"canonicalization_review":True,"unsafe_deserialization_blocked":True}); assert r["valid"] is True
def test_session_security_requires_all_controls():
    r=assess_session_security({"secure_cookie_policy":True,"http_only_policy":True,"same_site_policy":True,"session_expiry":True,"session_rotation":True,"csrf_governance":True}); assert r["valid"] is True
def test_api_security_requires_authz():
    r=assess_api_security({"authentication_required":True,"authorization_required":True,"object_level_authorization":True,"rate_limit_governance":True,"cors_governance":True,"error_sanitization":True,"security_headers":True,"request_size_governance":True}); assert r["valid"] is True
def test_owasp_control_coverage():
    r=assess_owasp_control_coverage({"access_control":True,"cryptographic_failures":True,"injection":True,"insecure_design":True,"security_misconfiguration":True,"vulnerable_components":True,"auth_failures":True,"integrity_failures":True,"logging_monitoring":True,"request_forgery":True}); assert r["valid"] is True
def test_no_active_attack(): assert ApplicationApiSecurityService().assess(1)["active_attack_test_executed"] is False
def test_no_production_change(): assert ApplicationApiSecurityService().assess(1)["production_changed"] is False
def test_no_external_connection(): assert ApplicationApiSecurityService().assess(1)["external_connection_opened"] is False
def test_no_secret_exposure(): assert ApplicationApiSecurityService().assess(1)["secret_values_exposed"] is False
def test_surface_count_preserved(): assert ApplicationApiSecurityService().assess(123)["surface_count"]==123
def test_session_not_rotated_for_real(): assert ApplicationApiSecurityService().assess(1)["session_security"]["real_session_rotated"] is False
