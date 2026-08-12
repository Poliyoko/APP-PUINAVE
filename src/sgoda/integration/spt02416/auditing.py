def assess_database_auditing(profile):
    checks={
        "security_event_logging":bool(profile.get("security_event_logging")),
        "privileged_action_logging":bool(profile.get("privileged_action_logging")),
        "failed_auth_logging":bool(profile.get("failed_auth_logging")),
        "schema_change_logging":bool(profile.get("schema_change_logging")),
        "log_integrity":bool(profile.get("log_integrity")),
    }
    return {"valid":all(checks.values()),**checks,"audit_configuration_changed":False}
