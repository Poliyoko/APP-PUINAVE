def assess_roles_privileges(profile):
    checks={
        "role_hierarchy_governance":bool(profile.get("role_hierarchy_governance")),
        "least_privilege":bool(profile.get("least_privilege")),
        "default_privileges_review":bool(profile.get("default_privileges_review")),
        "service_account_scope":bool(profile.get("service_account_scope")),
        "privileged_role_separation":bool(profile.get("privileged_role_separation")),
        "ownership_governance":bool(profile.get("ownership_governance")),
    }
    return {"valid":all(checks.values()),**checks,"real_role_changed":False}
