from .initializer import ProjectInitializer
from .constants import DEFAULT_DIRECTORIES, REQUIRED_PROJECT_FILES
class ProjectBuilder:
    def __init__(self,config): self.config=config; self.initializer=ProjectInitializer(config)
    def initialize(self,**kwargs): return self.initializer.initialize(**kwargs)
    def validate(self):
        req=[*(self.config.workspace/d for d in DEFAULT_DIRECTORIES),*(self.config.workspace/f for f in REQUIRED_PROJECT_FILES)]
        missing=[p for p in req if not p.exists()]
        return (not missing,missing)
