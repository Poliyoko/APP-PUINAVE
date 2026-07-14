"""Generador de directorios."""

from collections.abc import Iterable
from pathlib import Path


class FolderGenerator:
    """Crea directorios de forma idempotente."""

    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace

    def create(
        self,
        directories: Iterable[str],
        *,
        dry_run: bool = False,
    ) -> list[tuple[Path, bool]]:
        results: list[tuple[Path, bool]] = []
        for relative_directory in directories:
            path = self.workspace / relative_directory
            existed = path.exists()
            if not dry_run:
                path.mkdir(parents=True, exist_ok=True)
            results.append((path, not existed))
        return results
