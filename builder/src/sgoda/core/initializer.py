from dataclasses import dataclass
from pathlib import Path
from sgoda.generators.files import FileGenerator
from sgoda.generators.folders import FolderGenerator
from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES
from .templates import build_project_files
@dataclass(frozen=True, slots=True)
class InitializationResult:
    workspace:Path; created_directories:tuple[Path,...]; existing_directories:tuple[Path,...]; written_files:tuple[Path,...]; preserved_files:tuple[Path,...]
class ProjectInitializer:
    def __init__(self,config:BuilderConfig)->None:self.config=config
    def initialize(self,*,project_name:str,force:bool=False)->InitializationResult:
        dr=FolderGenerator(self.config.workspace).create(DEFAULT_DIRECTORIES,dry_run=self.config.dry_run)
        fr=FileGenerator(self.config.workspace).create(build_project_files(project_name),force=force,dry_run=self.config.dry_run)
        return InitializationResult(self.config.workspace,tuple(p for p,c in dr if c),tuple(p for p,c in dr if not c),tuple(p for p,c in fr if c),tuple(p for p,c in fr if not c))
