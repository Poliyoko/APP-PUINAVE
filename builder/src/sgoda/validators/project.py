from pathlib import Path
from sgoda.core import BuilderConfig, ProjectBuilder


def validate_project(workspace: Path) -> tuple[bool, list[Path]]:
    return ProjectBuilder(BuilderConfig.from_path(workspace)).validate()
