def assess_database_access(profile):
    checks={
        "least_privilege":bool(profile.get("least_privilege")),
        "service_identity_governance":bool(profile.get("service_identity_governance")),
        "admin_role_separation":bool(profile.get("admin_role_separation")),
        "credential_indirection":bool(profile.get("credential_indirection")),
        "network_scope_governance":bool(profile.get("network_scope_governance")),
    }
    return {"valid":all(checks.values()),**checks,"real_role_changed":False}
