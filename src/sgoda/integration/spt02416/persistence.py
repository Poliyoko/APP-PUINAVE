def assess_persistence_governance(profile):
    checks={
        "repository_migration_traceability":bool(profile.get("repository_migration_traceability")),
        "schema_versioning":bool(profile.get("schema_versioning")),
        "rollback_governance":bool(profile.get("rollback_governance")),
        "data_access_review":bool(profile.get("data_access_review")),
        "evidence_required":bool(profile.get("evidence_required")),
    }
    return {"valid":all(checks.values()),**checks}
