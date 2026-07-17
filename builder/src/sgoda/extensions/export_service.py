"""Exportación reproducible del ecosistema SGODA."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import shutil
import tempfile

from sgoda import __version__

from .archive_service import ArchiveService, sha256_file
from .catalog_service import CatalogService
from .package_manifest import PackageFile, PackageManifest


class ExportServiceError(RuntimeError):
    """Error de exportación."""


class ExportService:
    SCHEMA_VERSION = "1.0"

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.extensions = self.workspace / ".sgoda" / "extensions"
        self.archive = ArchiveService()

    def create(self, destination: str | Path) -> Path:
        if not self.extensions.is_dir():
            raise ExportServiceError("El workspace no contiene un ecosistema de extensiones.")
        CatalogService(self.workspace).rebuild()
        temporary_root = Path(tempfile.mkdtemp(prefix="sgoda-export-"))
        staging = temporary_root / "package"
        staging.mkdir()
        try:
            for relative in ("registry.json", "catalog.json", "plugins", "templates", "bundles"):
                source = self.extensions / relative
                target = staging / relative
                if source.is_dir():
                    shutil.copytree(
                        source, target,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".pytest_cache")
                    )
                elif source.is_file():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)

            files = tuple(
                PackageFile(
                    path=path.relative_to(staging).as_posix(),
                    sha256=sha256_file(path),
                    size=path.stat().st_size,
                )
                for path in sorted(staging.rglob("*"))
                if path.is_file()
            )
            stats = {
                "files": len(files),
                "plugins": len(list((staging / "plugins").glob("*"))) if (staging / "plugins").is_dir() else 0,
                "templates": len(list((staging / "templates").glob("*"))) if (staging / "templates").is_dir() else 0,
                "bundles": len(list((staging / "bundles").glob("*.bundle.json"))) if (staging / "bundles").is_dir() else 0,
            }
            manifest = PackageManifest(
                schema_version=self.SCHEMA_VERSION,
                builder_version=__version__,
                created_at=datetime.now(UTC).isoformat(),
                source_workspace=str(self.workspace),
                files=files,
                statistics=stats,
            )
            return self.archive.build(staging, Path(destination), manifest)
        finally:
            shutil.rmtree(temporary_root, ignore_errors=True)

    def verify(self, package: str | Path) -> dict:
        return self.archive.verify(Path(package))
