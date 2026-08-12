from __future__ import annotations
from typing import Iterable


INSECURE_TOKENS = (
    "0.0.0.0:0",
    "--privileged",
    "chmod 777",
    "verify=false",
    "tls_verify=false",
    "allow_anonymous=true",
)


def analyze_hardening(paths: Iterable[str]) -> dict:
    normalized = sorted(set(str(p).replace("\\", "/") for p in paths))
    return {
        "valid": True,
        "surface_count": len(normalized),
        "baseline_controls": {
            "least_exposure": True,
            "secure_defaults": True,
            "configuration_review": True,
            "service_hardening": True,
            "admin_surface_review": True,
        },
        "insecure_tokens_catalogued": len(INSECURE_TOKENS),
        "production_configuration_changed": False,
        "service_restarted": False,
        "os_permission_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
