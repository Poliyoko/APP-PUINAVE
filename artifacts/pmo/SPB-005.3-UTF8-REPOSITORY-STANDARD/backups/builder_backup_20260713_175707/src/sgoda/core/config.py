"""
SPB-002.1-F001
Configuracion global del SGODA Project Builder.
"""

from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class BuilderConfig:
    """Configuracion principal del Builder."""

    workspace: Path
    verbose: bool = False
    dry_run: bool = False

    @property
    def exists(self) -> bool:
        """Indica si el directorio de trabajo existe."""
        return self.workspace.exists()
