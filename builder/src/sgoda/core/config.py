"""Configuración del SGODA Project Builder."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class BuilderConfig:
    """Configuración utilizada por el Builder."""

    workspace: Path
    verbose: bool = False
    dry_run: bool = False

    @classmethod
    def from_path(
        cls,
        workspace: str | Path,
        *,
        verbose: bool = False,
        dry_run: bool = False,
    ) -> "BuilderConfig":
        return cls(
            workspace=Path(workspace).expanduser().resolve(),
            verbose=verbose,
            dry_run=dry_run,
        )
