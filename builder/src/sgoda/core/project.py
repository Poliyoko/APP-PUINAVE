from pathlib import Path

from sgoda.generators.files import FileGenerator
from sgoda.generators.folders import FolderGenerator

from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES, REQUIRED_PROJECT_FILES
from .templates import build_project_files


class ProjectBuilder:
    def __init__(self, config: BuilderConfig) -> None:
        self.config = config

    def initialize(self, *, project_name: str) -> None:
        FolderGenerator(self.config.workspace).create(DEFAULT_DIRECTORIES)
        FileGenerator(self.config.workspace).create(
            build_project_files(project_name)
        )

    def validate(self) -> tuple[bool, list[Path]]:
        required = [
            *(self.config.workspace / item for item in DEFAULT_DIRECTORIES),
            *(self.config.workspace / item for item in REQUIRED_PROJECT_FILES),
        ]
        missing = [path for path in required if not path.exists()]
        return not missing, missing
