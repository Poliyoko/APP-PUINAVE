"""Sistema de Identidad Cultural Configurable."""

from __future__ import annotations

from typing import Any

__all__ = [
    "CulturalApproval",
    "IdentityChange",
    "IdentityGovernanceError",
    "IdentityProfile",
    "IdentityRepository",
    "IdentityService",
    "export_api",
    "export_flutter",
    "export_web",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "CulturalApproval",
        "IdentityChange",
        "IdentityProfile",
    }:
        from . import models
        return getattr(models, name)

    if name == "IdentityRepository":
        from . import repository
        return getattr(repository, name)

    if name in {"IdentityGovernanceError", "IdentityService"}:
        from . import service
        return getattr(service, name)

    from . import exporter
    return getattr(exporter, name)