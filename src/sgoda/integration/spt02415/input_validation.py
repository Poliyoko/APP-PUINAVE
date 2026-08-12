def assess_input_validation(profile):
    checks={
        "allowlist_or_schema_validation":bool(profile.get("allowlist_or_schema_validation")),
        "size_limits":bool(profile.get("size_limits")),
        "type_validation":bool(profile.get("type_validation")),
        "canonicalization_review":bool(profile.get("canonicalization_review")),
        "unsafe_deserialization_blocked":bool(profile.get("unsafe_deserialization_blocked")),
    }
    return {"valid":all(checks.values()),**checks}
