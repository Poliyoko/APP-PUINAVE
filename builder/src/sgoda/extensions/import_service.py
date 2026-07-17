"""Importación transaccional de paquetes SGODA."""

from __future__ import annotations

from pathlib import Path
import shutil
import tempfile

from .archive_service import ArchiveError, ArchiveService
from .catalog_service import CatalogService


class ImportServiceError(RuntimeError):
    """Error de importación."""


class ImportService:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.extensions = self.workspace / ".sgoda" / "extensions"
        self.archive = ArchiveService()

    def verify(self, package: str | Path) -> dict:
        return self.archive.verify(Path(package))

    def import_package(
        self,
        package: str | Path,
        *,
        replace: bool = False,
        dry_run: bool = False,
    ) -> dict:
        package_path = Path(package).expanduser().resolve()
        verification = self.archive.verify(package_path)
        if not verification["valid"]:
            raise ImportServiceError("; ".join(verification["errors"]))
        if self.extensions.exists() and any(self.extensions.iterdir()) and not replace:
            raise ImportServiceError(
                "El workspace ya contiene extensiones; use --replace para restaurar."
            )
        if dry_run:
            return {
                "status": "PLANNED",
                "workspace": str(self.workspace),
                "package": str(package_path),
                "files": verification["files"],
                "replaced": replace,
            }

        temporary = Path(tempfile.mkdtemp(prefix="sgoda-import-"))
        extracted = temporary / "extracted"
        backup = temporary / "backup"
        existed = self.extensions.exists()
        try:
            self.archive.extract_verified(package_path, extracted)
            if existed:
                shutil.copytree(self.extensions, backup)
                shutil.rmtree(self.extensions)
            self.extensions.parent.mkdir(parents=True, exist_ok=True)
            self.extensions.mkdir(parents=True, exist_ok=True)
            for child in extracted.iterdir():
                if child.name == "manifest.json":
                    continue
                target = self.extensions / child.name
                if child.is_dir():
                    shutil.copytree(child, target)
                else:
                    shutil.copy2(child, target)
            CatalogService(self.workspace).rebuild()
        except Exception as exc:
            shutil.rmtree(self.extensions, ignore_errors=True)
            if existed and backup.exists():
                shutil.copytree(backup, self.extensions)
            raise ImportServiceError(f"Importación revertida: {exc}") from exc
        finally:
            shutil.rmtree(temporary, ignore_errors=True)

        return {
            "status": "IMPORTED",
            "workspace": str(self.workspace),
            "package": str(package_path),
            "files": verification["files"],
            "replaced": existed,
        }
