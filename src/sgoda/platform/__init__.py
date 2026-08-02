"""SPT-010 — Plataforma Digital Integrada."""

from .facade import IntegratedPlatformFacade
from .health import module_health, repository_health
from .models import Capability, PlatformRequest, PlatformResponse
from .registry import CapabilityRegistry, default_registry
from .runtime import build_runtime

__all__ = [
    "Capability",
    "CapabilityRegistry",
    "IntegratedPlatformFacade",
    "PlatformRequest",
    "PlatformResponse",
    "build_runtime",
    "default_registry",
    "module_health",
    "repository_health",
]