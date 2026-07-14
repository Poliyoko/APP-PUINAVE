from pathlib import Path
from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES, REQUIRED_PROJECT_FILES
from .initializer import InitializationResult, ProjectInitializer
class ProjectBuilder:
    def __init__(self,config:BuilderConfig)->None:self.config=config;self.initializer=ProjectInitializer(config)
    def initialize(self,*,project_name:str,force:bool=False)->InitializationResult:return self.initializer.initialize(project_name=project_name,force=force)
    def validate(self)->tuple[bool,list[Path]]:
        required=[*(self.config.workspace/i for i in DEFAULT_DIRECTORIES),*(self.config.workspace/i for i in REQUIRED_PROJECT_FILES)]
        missing=[p for p in required if not p.exists()];return not missing,missing
