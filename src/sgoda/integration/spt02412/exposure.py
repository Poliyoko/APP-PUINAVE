from __future__ import annotations
from typing import Iterable


def assess_exposure(paths: Iterable[str]) -> dict:
    items = sorted(set(str(p).replace("\\", "/") for p in paths))
    exposure_candidates = [
        p for p in items
        if any(token in p.lower() for token in (
            "api", "webhook", "port", "network", "proxy", "nginx",
            "fastapi", "n8n", "postgres", "docker", "compose"
        ))
    ]
    return {
        "valid": True,
        "surface_count": len(items),
        "exposure_candidate_count": len(exposure_candidates),
        "review_mode": "STATIC_NON_DESTRUCTIVE",
        "port_opened": False,
        "firewall_changed": False,
        "service_published": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
