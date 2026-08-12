def assess_migration_governance(profile):
    checks={
        "versioned_migrations":bool(profile.get("versioned_migrations")),
        "forward_only_review":bool(profile.get("forward_only_review")),
        "rollback_plan":bool(profile.get("rollback_plan")),
        "ddl_review":bool(profile.get("ddl_review")),
        "migration_checksums":bool(profile.get("migration_checksums")),
        "environment_promotion_governance":bool(profile.get("environment_promotion_governance")),
    }
    return {"valid":all(checks.values()),**checks,"migration_executed":False}
