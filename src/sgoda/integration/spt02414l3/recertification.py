from .models import RecertificationRecord

def build_recertification():
    return [
        RecertificationRecord("threat_governance","RECERTIFIED","SPT-024.14-Capa1"),
        RecertificationRecord("vulnerability_governance","RECERTIFIED","SPT-024.14-Capa1"),
        RecertificationRecord("impact_assessment","RECERTIFIED","SPT-024.14-Capa1"),
        RecertificationRecord("master_risk_register","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("risk_prioritization","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("treatment_plans","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("residual_risk","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("exceptions","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("risk_acceptance","RECERTIFIED","SPT-024.14-Capa2"),
    ]
