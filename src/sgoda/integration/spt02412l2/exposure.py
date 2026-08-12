from __future__ import annotations
from typing import Iterable


def exposure_baseline(paths: Iterable[str]) -> dict:
    items = sorted(set(str(p).replace("\\", "/") for p in paths))
    candidates = [
        p for p in items
        if any(token in p.lower() for token in (
            "api", "webhook", "port", "network", "proxy", "nginx",
            "fastapi", "n8n", "postgres", "docker", "compose", "service"
        ))
    ]
    return {
        "valid": True,
        "surface_count": len(items),
        "candidate_count": len(candidates),
        "mode": "STATIC_NON_DESTRUCTIVE",
        "port_opened": False,
        "firewall_changed": False,
        "service_published": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
