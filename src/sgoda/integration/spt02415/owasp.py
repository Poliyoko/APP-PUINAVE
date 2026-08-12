def assess_owasp_control_coverage(profile):
    checks={
        "access_control":bool(profile.get("access_control")),
        "cryptographic_failures":bool(profile.get("cryptographic_failures")),
        "injection":bool(profile.get("injection")),
        "insecure_design":bool(profile.get("insecure_design")),
        "security_misconfiguration":bool(profile.get("security_misconfiguration")),
        "vulnerable_components":bool(profile.get("vulnerable_components")),
        "auth_failures":bool(profile.get("auth_failures")),
        "integrity_failures":bool(profile.get("integrity_failures")),
        "logging_monitoring":bool(profile.get("logging_monitoring")),
        "request_forgery":bool(profile.get("request_forgery")),
    }
    return {"valid":all(checks.values()),**checks,"active_attack_test_executed":False}
