

"""
SGODA Project Builder
Core Package
"""

from .constants import (
    APP_NAME,
    VERSION,
    AUTHOR,
    COPYRIGHT,
    DEFAULT_DIRECTORIES,
)

from .config import BuilderConfig
from .project import ProjectBuilder

__all__ = [
    "APP_NAME",
    "VERSION",
    "AUTHOR",
    "COPYRIGHT",
    "DEFAULT_DIRECTORIES",
    "BuilderConfig",
    "ProjectBuilder",
]
