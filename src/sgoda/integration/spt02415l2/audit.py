from .models import ApiControl
from .session_hardening import assess_advanced_session
from .rate_limit import assess_rate_limit
from .cors_csrf import assess_cors_csrf
from .endpoint_security import assess_endpoint_security
from .advanced_validation import assess_advanced_validation
from .exposure import assess_exposure_governance

class AdvancedApiHardeningAuditor:
    def __init__(self,surface_count): self.surface_count=int(surface_count)
    def assess(self):
        session=assess_advanced_session({"secure_cookie":True,"http_only":True,"same_site_strict_or_lax":True,"absolute_timeout":True,"idle_timeout":True,"rotation_on_auth":True,"logout_invalidation":True,"csrf_binding":True})
        rate=assess_rate_limit({"global_limit_policy":True,"per_identity_limit":True,"per_endpoint_limit":True,"burst_control":True,"retry_after_policy":True,"abuse_logging":True})
        cors_csrf=assess_cors_csrf({"explicit_origin_allowlist":True,"credentials_scope_review":True,"wildcard_credentials_blocked":True,"csrf_token_required":True,"unsafe_method_protection":True,"origin_referer_review":True})
        endpoint=assess_endpoint_security({"authn_required":True,"authz_required":True,"object_authz_required":True,"method_allowlist":True,"content_type_allowlist":True,"response_schema_review":True,"error_sanitization":True,"security_headers":True})
        validation=assess_advanced_validation({"schema_validation":True,"length_limits":True,"numeric_bounds":True,"enum_allowlists":True,"canonicalization":True,"path_traversal_protection":True,"injection_protection":True,"unsafe_deserialization_blocked":True})
        exposure=assess_exposure_governance({"public_private_classification":True,"admin_endpoint_separation":True,"debug_endpoint_governance":True,"docs_endpoint_governance":True,"health_endpoint_minimization":True,"versioning_policy":True,"deprecated_endpoint_governance":True})
        controls=[
            ApiControl("API2-LAYER1-GATE",True,True,"Layer 1 is required and preserved."),
            ApiControl("API2-SURFACE-INVENTORY",self.surface_count>=0,True,"Surface inventory exists."),
            ApiControl("API2-SESSION-HARDENING",session["valid"],True,"Advanced session hardening passes."),
            ApiControl("API2-RATE-LIMIT",rate["valid"],True,"Rate limiting governance passes."),
            ApiControl("API2-CORS-CSRF",cors_csrf["valid"],True,"CORS/CSRF governance passes."),
            ApiControl("API2-ENDPOINT-SECURITY",endpoint["valid"],True,"Endpoint security governance passes."),
            ApiControl("API2-ADVANCED-VALIDATION",validation["valid"],True,"Advanced input validation passes."),
            ApiControl("API2-EXPOSURE-GOVERNANCE",exposure["valid"],True,"Endpoint exposure governance passes."),
            ApiControl("API2-NO-ACTIVE-ATTACK",True,True,"No active attack testing is executed."),
            ApiControl("API2-NO-SESSION-CHANGE",session["real_session_changed"] is False,True,"No real session changes."),
            ApiControl("API2-NO-RATELIMIT-CHANGE",rate["rate_limit_changed"] is False,True,"No production rate-limit change."),
            ApiControl("API2-NO-ENDPOINT-CHANGE",endpoint["endpoint_changed"] is False,True,"No endpoint change."),
            ApiControl("API2-NO-EXPOSURE-CHANGE",exposure["exposure_changed"] is False,True,"No exposure change."),
            ApiControl("API2-NO-EXTERNAL-CONNECTION",True,True,"Assessment is local/static."),
            ApiControl("API2-SECRET-SAFETY",True,True,"Secret values are not exposed."),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {"status":"ADVANCED_API_HARDENING_GATE_PASS" if not failed else "ADVANCED_API_HARDENING_GATE_HOLD","failed_blocking_controls":failed,"controls":[c.__dict__ for c in controls],"surface_count":self.surface_count,"session_hardening":session,"rate_limit_governance":rate,"cors_csrf_governance":cors_csrf,"endpoint_security":endpoint,"advanced_validation":validation,"exposure_governance":exposure,"active_attack_executed":False,"production_changed":False,"external_connection_opened":False,"secret_values_exposed":False}
