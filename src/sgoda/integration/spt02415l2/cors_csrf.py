def assess_cors_csrf(profile):
    checks={"explicit_origin_allowlist":bool(profile.get("explicit_origin_allowlist")),"credentials_scope_review":bool(profile.get("credentials_scope_review")),"wildcard_credentials_blocked":bool(profile.get("wildcard_credentials_blocked")),"csrf_token_required":bool(profile.get("csrf_token_required")),"unsafe_method_protection":bool(profile.get("unsafe_method_protection")),"origin_referer_review":bool(profile.get("origin_referer_review"))}
    return {"valid":all(checks.values()),**checks}
