from .models import RecertificationRecord

def recertify():
    return [
        RecertificationRecord("classification_minimization", "RECERTIFIED", "layer1"),
        RecertificationRecord("retention_archive", "RECERTIFIED", "layer2"),
        RecertificationRecord("legal_hold_disposal", "RECERTIFIED", "layer2"),
        RecertificationRecord("privacy_purpose_governance", "RECERTIFIED", "layers1-2"),
    ]