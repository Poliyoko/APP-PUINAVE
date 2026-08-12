def assess_session_security(profile):
    checks={
        "secure_cookie_policy":bool(profile.get("secure_cookie_policy")),
        "http_only_policy":bool(profile.get("http_only_policy")),
        "same_site_policy":bool(profile.get("same_site_policy")),
        "session_expiry":bool(profile.get("session_expiry")),
        "session_rotation":bool(profile.get("session_rotation")),
        "csrf_governance":bool(profile.get("csrf_governance")),
    }
    return {"valid":all(checks.values()),**checks,"real_session_rotated":False}
