"""Motor principal del SGODA Project Builder."""

from pathlib import Path
from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES, REQUIRED_PROJECT_FILES
from .initializer import InitializationResult, ProjectInitializer


class ProjectBuilder:
    def __init__(self, config: BuilderConfig) -> None:
        self.config = config
        self.initializer = ProjectInitializer(config)

    def initialize(self, *, project_name: str, force: bool = False) -> InitializationResult:
        return self.initializer.initialize(project_name=project_name, force=force)

    def validate(self) -> tuple[bool, list[Path]]:
        required_paths = [
            *(self.config.workspace / directory for directory in DEFAULT_DIRECTORIES),
            *(self.config.workspace / relative_file for relative_file in REQUIRED_PROJECT_FILES),
        ]
        missing = [path for path in required_paths if not path.exists()]
        return not missing, missing
