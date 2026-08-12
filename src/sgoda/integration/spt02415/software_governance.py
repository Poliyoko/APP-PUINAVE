def assess_software_security_governance(profile):
    checks={
        "secure_coding_policy":bool(profile.get("secure_coding_policy")),
        "dependency_review":bool(profile.get("dependency_review")),
        "secret_indirection":bool(profile.get("secret_indirection")),
        "review_required":bool(profile.get("review_required")),
        "security_tests_required":bool(profile.get("security_tests_required")),
        "evidence_required":bool(profile.get("evidence_required")),
    }
    return {"valid":all(checks.values()),**checks}
