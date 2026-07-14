from pathlib import Path
from sgoda.core import BuilderConfig, ProjectBuilder

def validate_project(workspace: Path):
    return ProjectBuilder(BuilderConfig.from_path(workspace)).validate()
