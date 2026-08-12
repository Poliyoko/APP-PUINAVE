from .models import RecertificationRecord

def build_recertification():
    return [
        RecertificationRecord("database_access_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("secure_query_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("data_integrity_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("database_auditing_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("postgresql_hardening_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("persistence_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("roles_privileges_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("schema_security_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("migration_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("advanced_database_auditing","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("transactional_integrity_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("persistence_protection_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("postgresql_advanced_governance","RECERTIFIED","SPT-024.16-Capa2"),
    ]
