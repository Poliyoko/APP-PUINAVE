"""Generación de directorios."""

from pathlib import Path
from typing import Iterable


class FolderGenerator:
    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace

    def create(
        self,
        directories: Iterable[str],
        *,
        dry_run: bool = False,
    ) -> list[tuple[Path, bool]]:
        results = []

        for relative_path in directories:
            path = self.workspace / relative_path
            existed = path.exists()

            if not dry_run:
                path.mkdir(parents=True, exist_ok=True)

            results.append((path, not existed))

        return results
