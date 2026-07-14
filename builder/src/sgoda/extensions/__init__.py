"""Sistema profesional de plugins y plantillas SGODA."""

from .manager import (
    ExtensionManager,
    ExtensionManagerError,
    InstallResult,
    RenderResult,
)
from .models import ExtensionManifest, ExtensionRecord
from .registry import ExtensionRegistry, ExtensionRegistryError
from .validator import (
    ExtensionValidationError,
    load_manifest,
    requirement_satisfied,
    validate_manifest,
    validate_relative_path,
)

__all__ = [
    "ExtensionManager",
    "ExtensionManagerError",
    "ExtensionManifest",
    "ExtensionRecord",
    "ExtensionRegistry",
    "ExtensionRegistryError",
    "ExtensionValidationError",
    "InstallResult",
    "RenderResult",
    "load_manifest",
    "requirement_satisfied",
    "validate_manifest",
    "validate_relative_path",
]
