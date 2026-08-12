from .models import RecertificationRecord


def recertify():
    return [
        RecertificationRecord("secure_configuration_baseline", "RECERTIFIED", "layer1-layer2"),
        RecertificationRecord("service_governance", "RECERTIFIED", "layer2"),
        RecertificationRecord("port_exposure_governance", "RECERTIFIED", "layer1-layer2"),
        RecertificationRecord("infrastructure_change_governance", "RECERTIFIED", "layer2"),
        RecertificationRecord("secret_indirection", "RECERTIFIED", "layer1-layer2"),
    ]
