def assess_data_integrity(profile):
    checks={
        "constraints_governance":bool(profile.get("constraints_governance")),
        "referential_integrity":bool(profile.get("referential_integrity")),
        "migration_review":bool(profile.get("migration_review")),
        "backup_integrity_reference":bool(profile.get("backup_integrity_reference")),
        "hash_evidence":bool(profile.get("hash_evidence")),
    }
    return {"valid":all(checks.values()),**checks,"data_changed":False}
