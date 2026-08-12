def assess_persistence_protection(profile):
    checks={
        "backup_reference":bool(profile.get("backup_reference")),
        "restore_governance":bool(profile.get("restore_governance")),
        "retention_alignment":bool(profile.get("retention_alignment")),
        "encryption_policy_reference":bool(profile.get("encryption_policy_reference")),
        "integrity_hashes":bool(profile.get("integrity_hashes")),
        "sensitive_data_classification":bool(profile.get("sensitive_data_classification")),
    }
    return {"valid":all(checks.values()),**checks,"persistence_changed":False}
