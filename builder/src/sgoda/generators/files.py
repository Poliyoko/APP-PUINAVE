"""Generador seguro de archivos base para proyectos SGODA."""

from pathlib import Path
from typing import Mapping


class FileGenerator:
    """Crea archivos sin sobrescribirlos salvo autorización explícita."""

    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace

    def create(self, files: Mapping[str, str], *, force: bool = False, dry_run: bool = False) -> list[tuple[Path, bool]]:
        results: list[tuple[Path, bool]] = []
        for relative_path, content in files.items():
            path = self.workspace / relative_path
            should_write = force or not path.exists()
            if should_write and not dry_run:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            results.append((path, should_write))
        return results
