"""Servicio de inicialización profesional de proyectos SGODA."""

from dataclasses import dataclass
from pathlib import Path

from sgoda.generators.files import FileGenerator
from sgoda.generators.folders import FolderGenerator

from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES
from .templates import build_project_files


@dataclass(frozen=True, slots=True)
class InitializationResult:
    workspace: Path
    created_directories: tuple[Path, ...]
    existing_directories: tuple[Path, ...]
    written_files: tuple[Path, ...]
    preserved_files: tuple[Path, ...]


class ProjectInitializer:
    def __init__(self, config: BuilderConfig) -> None:
        self.config = config

    def initialize(
        self,
        *,
        project_name: str,
        force: bool = False,
    ) -> InitializationResult:
        directory_results = FolderGenerator(self.config.workspace).create(
            DEFAULT_DIRECTORIES,
            dry_run=self.config.dry_run,
        )
        file_results = FileGenerator(self.config.workspace).create(
            build_project_files(project_name),
            force=force,
            dry_run=self.config.dry_run,
        )
        return InitializationResult(
            workspace=self.config.workspace,
            created_directories=tuple(
                path for path, created in directory_results if created
            ),
            existing_directories=tuple(
                path for path, created in directory_results if not created
            ),
            written_files=tuple(
                path for path, written in file_results if written
            ),
            preserved_files=tuple(
                path for path, written in file_results if not written
            ),
        )
