"""Gestión avanzada del ciclo de vida SGODA."""

from .migrations import CURRENT_SCHEMA_VERSION, SUPPORTED_SCHEMA_VERSIONS
from .migrator import MigrationError, ProjectMigrator
from .models import MigrationReport, MigrationStep

__all__ = [
    "CURRENT_SCHEMA_VERSION",
    "MigrationError",
    "MigrationReport",
    "MigrationStep",
    "ProjectMigrator",
    "SUPPORTED_SCHEMA_VERSIONS",
]

from .repair import ProjectRepairer, RepairAction, RepairReport
