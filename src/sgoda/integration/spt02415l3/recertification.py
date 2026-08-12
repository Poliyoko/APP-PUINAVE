from .models import RecertificationRecord

def build_recertification():
    return [
        RecertificationRecord("input_validation","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("session_security","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("api_authentication_authorization","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("object_level_authorization","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("owasp_control_coverage","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("software_security_governance","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("advanced_session_hardening","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("rate_limit_governance","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("cors_csrf_governance","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("endpoint_security_governance","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("advanced_input_validation","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("api_exposure_governance","RECERTIFIED","SPT-024.15-Capa2"),
    ]
