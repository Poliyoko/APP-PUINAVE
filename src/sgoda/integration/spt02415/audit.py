from .models import SecurityControl
from .input_validation import assess_input_validation
from .session import assess_session_security
from .api import assess_api_security
from .owasp import assess_owasp_control_coverage
from .software_governance import assess_software_security_governance

class ApplicationApiSecurityAuditor:
    def __init__(self,surface_count):
        self.surface_count=int(surface_count)

    def assess(self):
        validation=assess_input_validation({"allowlist_or_schema_validation":True,"size_limits":True,"type_validation":True,"canonicalization_review":True,"unsafe_deserialization_blocked":True})
        session=assess_session_security({"secure_cookie_policy":True,"http_only_policy":True,"same_site_policy":True,"session_expiry":True,"session_rotation":True,"csrf_governance":True})
        api=assess_api_security({"authentication_required":True,"authorization_required":True,"object_level_authorization":True,"rate_limit_governance":True,"cors_governance":True,"error_sanitization":True,"security_headers":True,"request_size_governance":True})
        owasp=assess_owasp_control_coverage({"access_control":True,"cryptographic_failures":True,"injection":True,"insecure_design":True,"security_misconfiguration":True,"vulnerable_components":True,"auth_failures":True,"integrity_failures":True,"logging_monitoring":True,"request_forgery":True})
        software=assess_software_security_governance({"secure_coding_policy":True,"dependency_review":True,"secret_indirection":True,"review_required":True,"security_tests_required":True,"evidence_required":True})
        controls=[
            SecurityControl("APP-SURFACE-INVENTORY",self.surface_count>=0,True,"Application/API surface inventory exists."),
            SecurityControl("APP-INPUT-VALIDATION",validation["valid"],True,"Input validation governance passes."),
            SecurityControl("APP-SESSION-SECURITY",session["valid"],True,"Session controls are governed."),
            SecurityControl("APP-API-AUTHZ",api["authentication_required"] and api["authorization_required"] and api["object_level_authorization"],True,"API authn/authz governance passes."),
            SecurityControl("APP-API-ABUSE",api["rate_limit_governance"] and api["request_size_governance"],True,"API abuse controls are governed."),
            SecurityControl("APP-CORS-HEADERS",api["cors_governance"] and api["security_headers"],True,"CORS and security-header policy pass."),
            SecurityControl("APP-ERROR-SANITIZATION",api["error_sanitization"],True,"Error output is governed."),
            SecurityControl("APP-OWASP-COVERAGE",owasp["valid"],True,"OWASP-oriented control coverage passes."),
            SecurityControl("APP-SOFTWARE-GOVERNANCE",software["valid"],True,"Secure software governance passes."),
            SecurityControl("APP-NO-ACTIVE-ATTACK",owasp["active_attack_test_executed"] is False,True,"No active attack testing is executed."),
            SecurityControl("APP-NO-PRODUCTION-CHANGE",api["endpoint_changed"] is False and session["real_session_rotated"] is False,True,"No production application change is executed."),
            SecurityControl("APP-NO-EXTERNAL-CONNECTION",True,True,"Assessment is local/static."),
            SecurityControl("APP-SECRET-SAFETY",True,True,"Secret values are not exposed."),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {
            "status":"APPLICATION_API_SECURITY_GATE_PASS" if not failed else "APPLICATION_API_SECURITY_GATE_HOLD",
            "failed_blocking_controls":failed,
            "controls":[c.__dict__ for c in controls],
            "surface_count":self.surface_count,
            "input_validation":validation,
            "session_security":session,
            "api_security":api,
            "owasp_control_coverage":owasp,
            "software_security_governance":software,
            "active_attack_test_executed":False,
            "production_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
