"""
Motor principal del SGODA Project Builder.
"""

from pathlib import Path

from .config import BuilderConfig
from .constants import DEFAULT_DIRECTORIES


class ProjectBuilder:
    """
    Constructor principal del proyecto.
    """

    def __init__(self, config: BuilderConfig):

        self.config = config

    def create_structure(self):

        root = self.config.workspace

        root.mkdir(parents=True, exist_ok=True)

        created = []

        for directory in DEFAULT_DIRECTORIES:

            path = root / directory

            path.mkdir(parents=True, exist_ok=True)

            created.append(path)

        return created

    def validate(self):

        return self.config.exists
    