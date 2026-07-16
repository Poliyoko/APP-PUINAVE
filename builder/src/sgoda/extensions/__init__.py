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


from .compatibility import CompatibilityError, parse_version, requirement_satisfied
from .dependency_resolver import DependencyIssue, PluginDependencyResolver
from .plugin_doctor import PluginDoctor, PluginDoctorReport
from .plugin_state import PluginStateResult, PluginStateService

__all__ += [
    "CompatibilityError",
    "DependencyIssue",
    "PluginDependencyResolver",
    "PluginDoctor",
    "PluginDoctorReport",
    "PluginStateResult",
    "PluginStateService",
    "parse_version",
    "requirement_satisfied",
]
