def assess_postgresql_hardening(profile):
    checks={
        "ssl_policy":bool(profile.get("ssl_policy")),
        "search_path_governance":bool(profile.get("search_path_governance")),
        "public_schema_governance":bool(profile.get("public_schema_governance")),
        "extension_governance":bool(profile.get("extension_governance")),
        "statement_timeout_governance":bool(profile.get("statement_timeout_governance")),
        "idle_transaction_timeout_governance":bool(profile.get("idle_transaction_timeout_governance")),
    }
    return {"valid":all(checks.values()),**checks,"postgresql_configuration_changed":False}
