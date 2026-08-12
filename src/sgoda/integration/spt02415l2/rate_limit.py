def assess_rate_limit(profile):
    checks={"global_limit_policy":bool(profile.get("global_limit_policy")),"per_identity_limit":bool(profile.get("per_identity_limit")),"per_endpoint_limit":bool(profile.get("per_endpoint_limit")),"burst_control":bool(profile.get("burst_control")),"retry_after_policy":bool(profile.get("retry_after_policy")),"abuse_logging":bool(profile.get("abuse_logging"))}
    return {"valid":all(checks.values()),**checks,"rate_limit_changed":False}
