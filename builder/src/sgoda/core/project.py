"""Motor principal del Builder."""

from pathlib import Path

from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES, REQUIRED_PROJECT_FILES
from .initializer import InitializationResult, ProjectInitializer


class ProjectBuilder:
    def __init__(self, config: BuilderConfig) -> None:
        self.config = config

    def initialize(
        self,
        *,
        project_name: str,
        force: bool = False,
    ) -> InitializationResult:
        return ProjectInitializer(self.config).initialize(
            project_name=project_name,
            force=force,
        )

    def validate(self) -> tuple[bool, list[Path]]:
        required = [
            *(self.config.workspace / item for item in DEFAULT_DIRECTORIES),
            *(
                self.config.workspace / item
                for item in REQUIRED_PROJECT_FILES
            ),
        ]
        missing = [path for path in required if not path.exists()]
        return not missing, missing
