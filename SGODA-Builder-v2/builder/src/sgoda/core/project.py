from pathlib import Path
from sgoda.generators import FolderGenerator
from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES

class ProjectBuilder:
    def __init__(self, config: BuilderConfig) -> None:
        self.config=config
        self.folder_generator=FolderGenerator(config.workspace)

    def initialize(self) -> list[tuple[Path, bool]]:
        if not self.config.dry_run:
            self.config.workspace.mkdir(parents=True, exist_ok=True)
        return self.folder_generator.create(DEFAULT_DIRECTORIES, dry_run=self.config.dry_run)

    def validate(self) -> tuple[bool, list[Path]]:
        missing=[self.config.workspace/d for d in DEFAULT_DIRECTORIES if not (self.config.workspace/d).is_dir()]
        return (not missing, missing)
