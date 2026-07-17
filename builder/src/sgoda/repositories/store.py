"""Persistencia atómica del registro de repositorios."""

from __future__ import annotations

from pathlib import Path
import os
import tempfile

from .models import Repository, RepositoryRegistry
from .serializers import dumps_registry, loads_registry


class RepositoryStoreError(RuntimeError):
    """Error de almacenamiento de repositorios."""


class RepositoryStore:
    SCHEMA_VERSION = "1.0"

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.directory = self.workspace / ".sgoda" / "repositories"
        self.path = self.directory / "repositories.json"

    def load(self) -> RepositoryRegistry:
        if not self.path.exists():
            return RepositoryRegistry(self.SCHEMA_VERSION, ())
        try:
            return loads_registry(self.path.read_text(encoding="utf-8-sig"))
        except OSError as exc:
            raise RepositoryStoreError(f"No se pudo leer {self.path}: {exc}") from exc

    def save(self, repositories: tuple[Repository, ...] | list[Repository]) -> None:
        self.directory.mkdir(parents=True, exist_ok=True)
        registry = RepositoryRegistry(
            self.SCHEMA_VERSION,
            tuple(sorted(repositories, key=lambda item: (-item.priority, item.name))),
        )
        descriptor, temporary_name = tempfile.mkstemp(
            prefix="repositories-", suffix=".tmp", dir=self.directory
        )
        temporary = Path(temporary_name)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
                stream.write(dumps_registry(registry))
                stream.flush()
                os.fsync(stream.fileno())
            temporary.replace(self.path)
        except OSError as exc:
            temporary.unlink(missing_ok=True)
            raise RepositoryStoreError(f"No se pudo guardar {self.path}: {exc}") from exc

    def list(self) -> tuple[Repository, ...]:
        return self.load().repositories

    def get(self, name: str) -> Repository | None:
        return next((item for item in self.list() if item.name == name), None)
