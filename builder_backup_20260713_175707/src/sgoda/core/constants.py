"""
Constantes globales del SGODA Project Builder.
"""

APP_NAME = "SGODA Project Builder"

VERSION = "0.2.0"

AUTHOR = "Proyecto SGODA-PUINAVE"

COPYRIGHT = "(C) 2026 Proyecto SGODA-PUINAVE"

DEFAULT_DIRECTORIES = [
    "backend",
    "frontend",
    "mobile",
    "database",
    "automation",
    "builder",
    "docs",
    "scripts",
    "data",
    "media",
    "tests",
]



"""
Configuración global del Builder.
"""

from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class BuilderConfig:
    """
    Configuración principal del Builder.
    """

    workspace: Path
    verbose: bool = False
    dry_run: bool = False

    @property
    def exists(self) -> bool:
        return self.workspace.exists()
    
