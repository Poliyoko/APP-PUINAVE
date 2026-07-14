from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class BuilderConfig:
    workspace: Path

    @classmethod
    def from_path(cls, workspace: str | Path) -> "BuilderConfig":
        return cls(Path(workspace).expanduser().resolve())
