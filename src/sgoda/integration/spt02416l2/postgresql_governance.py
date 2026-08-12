def assess_postgresql_governance(profile):
    checks={
        "ssl_mode_policy":bool(profile.get("ssl_mode_policy")),
        "connection_limit_governance":bool(profile.get("connection_limit_governance")),
        "statement_timeout_governance":bool(profile.get("statement_timeout_governance")),
        "idle_transaction_timeout_governance":bool(profile.get("idle_transaction_timeout_governance")),
        "extension_allowlist":bool(profile.get("extension_allowlist")),
        "logging_policy":bool(profile.get("logging_policy")),
        "configuration_drift_review":bool(profile.get("configuration_drift_review")),
    }
    return {"valid":all(checks.values()),**checks,"postgresql_configuration_changed":False}
