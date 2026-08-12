def assess_schema_security(profile):
    checks={
        "public_schema_governance":bool(profile.get("public_schema_governance")),
        "search_path_governance":bool(profile.get("search_path_governance")),
        "schema_owner_review":bool(profile.get("schema_owner_review")),
        "create_privilege_review":bool(profile.get("create_privilege_review")),
        "cross_schema_access_review":bool(profile.get("cross_schema_access_review")),
        "extension_schema_governance":bool(profile.get("extension_schema_governance")),
    }
    return {"valid":all(checks.values()),**checks,"schema_changed":False}
