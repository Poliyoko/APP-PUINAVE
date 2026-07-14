from dataclasses import dataclass
from pathlib import Path
@dataclass(frozen=True,slots=True)
class BuilderConfig:
    workspace: Path
    verbose: bool=False
    dry_run: bool=False
    @classmethod
    def from_path(cls,workspace,**kwargs): return cls(Path(workspace).expanduser().resolve(),**kwargs)
