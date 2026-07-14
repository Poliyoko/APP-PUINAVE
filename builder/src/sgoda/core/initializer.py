from dataclasses import dataclass
from pathlib import Path
from sgoda.generators import FileGenerator, FolderGenerator
from .constants import DEFAULT_DIRECTORIES
import json
@dataclass(frozen=True,slots=True)
class InitializationResult:
    workspace:Path
    created_directories:tuple[Path,...]
    existing_directories:tuple[Path,...]
    written_files:tuple[Path,...]
    preserved_files:tuple[Path,...]
class ProjectInitializer:
    def __init__(self,config): self.config=config
    def initialize(self,*,project_name,force=False):
        dirs=FolderGenerator(self.config.workspace).create(DEFAULT_DIRECTORIES,dry_run=self.config.dry_run)
        files={"README.md":f"# {project_name}\n","sgoda.project.json":json.dumps({"project":{"name":project_name,"type":"SGODA"}},indent=2),"data/json/palabras.json":json.dumps({"records":[]},indent=2)}
        fr=FileGenerator(self.config.workspace).create(files,force=force,dry_run=self.config.dry_run)
        return InitializationResult(self.config.workspace,tuple(p for p,c in dirs if c),tuple(p for p,c in dirs if not c),tuple(p for p,w in fr if w),tuple(p for p,w in fr if not w))
