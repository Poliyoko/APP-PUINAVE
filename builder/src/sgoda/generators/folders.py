from pathlib import Path
from typing import Iterable


class FolderGenerator:
    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace

    def create(self, directories: Iterable[str]) -> None:
        for relative_path in directories:
            (self.workspace / relative_path).mkdir(
                parents=True, exist_ok=True
            )
