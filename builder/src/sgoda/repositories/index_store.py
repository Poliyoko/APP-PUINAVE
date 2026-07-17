"""Caché atómica y recuperable de índices remotos."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import os
import shutil
import tempfile

from .index_models import RepositoryIndex, SyncMetadata
from .index_serializers import (
    dumps_index,
    dumps_metadata,
    loads_index,
    loads_metadata,
)


class IndexStoreError(RuntimeError):
    """Error de acceso a la caché de índices."""


class IndexStore:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.cache_root = self.workspace / ".sgoda" / "repositories" / "cache"

    def directory(self, repository: str) -> Path:
        return self.cache_root / repository

    def index_path(self, repository: str) -> Path:
        return self.directory(repository) / "index.json"

    def metadata_path(self, repository: str) -> Path:
        return self.directory(repository) / "metadata.json"

    def previous_directory(self, repository: str) -> Path:
        return self.directory(repository) / "previous"

    def exists(self, repository: str) -> bool:
        return self.index_path(repository).is_file()

    def load_index(self, repository: str) -> RepositoryIndex:
        path = self.index_path(repository)
        if not path.exists():
            raise IndexStoreError(f"No existe índice en caché para: {repository}")
        try:
            return loads_index(path.read_text(encoding="utf-8-sig"))
        except OSError as exc:
            raise IndexStoreError(f"No se pudo leer {path}: {exc}") from exc

    def load_metadata(self, repository: str) -> SyncMetadata | None:
        path = self.metadata_path(repository)
        if not path.exists():
            return None
        try:
            return loads_metadata(path.read_text(encoding="utf-8-sig"))
        except OSError as exc:
            raise IndexStoreError(f"No se pudo leer {path}: {exc}") from exc

    def save(self, repository: str, index: RepositoryIndex, metadata: SyncMetadata) -> None:
        directory = self.directory(repository)
        directory.mkdir(parents=True, exist_ok=True)
        current_index = self.index_path(repository)
        current_metadata = self.metadata_path(repository)

        if current_index.exists():
            previous = self.previous_directory(repository)
            previous.mkdir(parents=True, exist_ok=True)
            stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S%fZ")
            shutil.copy2(current_index, previous / f"index-{stamp}.json")
            if current_metadata.exists():
                shutil.copy2(current_metadata, previous / f"metadata-{stamp}.json")

        self._atomic_write(current_index, dumps_index(index))
        self._atomic_write(current_metadata, dumps_metadata(metadata))

    @staticmethod
    def _atomic_write(path: Path, content: str) -> None:
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f"{path.stem}-", suffix=".tmp", dir=path.parent
        )
        temporary = Path(temporary_name)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            temporary.replace(path)
        except OSError as exc:
            temporary.unlink(missing_ok=True)
            raise IndexStoreError(f"No se pudo guardar {path}: {exc}") from exc

    def list_cached(self) -> tuple[str, ...]:
        if not self.cache_root.exists():
            return ()
        return tuple(
            sorted(
                path.name
                for path in self.cache_root.iterdir()
                if path.is_dir() and (path / "index.json").is_file()
            )
        )
