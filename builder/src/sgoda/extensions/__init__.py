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


from .plugin_updater import (
    PluginUpdateError,
    PluginUpdateResult,
    PluginUpdater,
)

__all__ += [
    "PluginUpdateError",
    "PluginUpdateResult",
    "PluginUpdater",
]


from .integrity import (
    IntegritySnapshot,
    PluginIntegrityResult,
    calculate_file_hashes,
    calculate_manifest_hash,
    calculate_tree_checksum,
    create_integrity_snapshot,
    sha256_file,
    verify_integrity,
)
from .plugin_integrity import PluginIntegrityService

__all__ += [
    "IntegritySnapshot",
    "PluginIntegrityResult",
    "PluginIntegrityService",
    "calculate_file_hashes",
    "calculate_manifest_hash",
    "calculate_tree_checksum",
    "create_integrity_snapshot",
    "sha256_file",
    "verify_integrity",
]


from .template_doctor import (
    TemplateDiagnostic,
    TemplateDoctor,
    TemplateDoctorReport,
)
from .template_models import (
    TemplateMetadata,
    TemplateStateResult,
    TemplateVariable,
)
from .template_state import TemplateStateService
from .template_validator import (
    TemplateValidationError,
    TemplateValidator,
)

__all__ += [
    "TemplateDiagnostic",
    "TemplateDoctor",
    "TemplateDoctorReport",
    "TemplateMetadata",
    "TemplateStateResult",
    "TemplateStateService",
    "TemplateValidationError",
    "TemplateValidator",
    "TemplateVariable",
]

from .template_updater import TemplateUpdateError, TemplateUpdateResult, TemplateUpdater
from .template_versions import TemplateBackup, TemplateVersionService
__all__ += ["TemplateBackup","TemplateUpdateError","TemplateUpdateResult","TemplateUpdater","TemplateVersionService"]
