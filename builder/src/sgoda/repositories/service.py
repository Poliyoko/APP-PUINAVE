"""Casos de uso de gestión de repositorios remotos."""

from __future__ import annotations

from pathlib import Path

from .models import Repository
from .store import RepositoryStore
from .validator import normalize_name, normalize_url, validate_priority


class RepositoryServiceError(RuntimeError):
    """Operación de repositorio no válida."""


class RepositoryService:
    def __init__(self, workspace: str | Path) -> None:
        self.store = RepositoryStore(workspace)

    def add(
        self,
        name: str,
        url: str,
        *,
        priority: int = 100,
        trusted: bool = False,
        enabled: bool = True,
        force: bool = False,
    ) -> Repository:
        normalized_name = normalize_name(name)
        normalized_url = normalize_url(url)
        validated_priority = validate_priority(priority)
        repositories = list(self.store.list())
        existing = next((item for item in repositories if item.name == normalized_name), None)
        if existing is not None and not force:
            raise RepositoryServiceError(
                f"El repositorio '{normalized_name}' ya existe; use --force para actualizarlo."
            )
        if any(item.url == normalized_url and item.name != normalized_name for item in repositories):
            raise RepositoryServiceError(
                f"La URL ya está registrada en otro repositorio: {normalized_url}"
            )
        if existing is None:
            result = Repository(
                name=normalized_name,
                url=normalized_url,
                enabled=enabled,
                priority=validated_priority,
                trusted=trusted,
            )
            repositories.append(result)
        else:
            result = existing.with_changes(
                url=normalized_url,
                enabled=enabled,
                priority=validated_priority,
                trusted=trusted,
            )
            repositories = [
                result if item.name == normalized_name else item for item in repositories
            ]
        self.store.save(repositories)
        return result

    def remove(self, name: str) -> Repository:
        normalized = normalize_name(name)
        repositories = list(self.store.list())
        current = next((item for item in repositories if item.name == normalized), None)
        if current is None:
            raise RepositoryServiceError(f"Repositorio no encontrado: {normalized}")
        self.store.save([item for item in repositories if item.name != normalized])
        return current

    def set_enabled(self, name: str, enabled: bool) -> Repository:
        normalized = normalize_name(name)
        repositories = list(self.store.list())
        current = next((item for item in repositories if item.name == normalized), None)
        if current is None:
            raise RepositoryServiceError(f"Repositorio no encontrado: {normalized}")
        updated = current.with_changes(enabled=enabled)
        self.store.save([updated if item.name == normalized else item for item in repositories])
        return updated

    def info(self, name: str) -> Repository:
        normalized = normalize_name(name)
        result = self.store.get(normalized)
        if result is None:
            raise RepositoryServiceError(f"Repositorio no encontrado: {normalized}")
        return result

    def list(self, *, enabled_only: bool = False) -> tuple[Repository, ...]:
        repositories = self.store.list()
        if enabled_only:
            repositories = tuple(item for item in repositories if item.enabled)
        return repositories
