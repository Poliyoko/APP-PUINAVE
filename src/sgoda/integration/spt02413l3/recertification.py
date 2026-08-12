from .models import RecertificationRecord

def recertify():
    return [
        RecertificationRecord("backup_governance", "RECERTIFIED", "SPT-024.13-Capa1"),
        RecertificationRecord("recovery_governance", "RECERTIFIED", "SPT-024.13-Capas1-2"),
        RecertificationRecord("rto_rpo_governance", "RECERTIFIED", "SPT-024.13-Capas1-2"),
        RecertificationRecord("availability_resilience", "RECERTIFIED", "SPT-024.13-Capa1"),
        RecertificationRecord("redundancy_governance", "RECERTIFIED", "SPT-024.13-Capa2"),
        RecertificationRecord("controlled_failover", "RECERTIFIED", "SPT-024.13-Capa2"),
        RecertificationRecord("contingency_governance", "RECERTIFIED", "SPT-024.13-Capa1"),
    ]
