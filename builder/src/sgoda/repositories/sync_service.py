"""Orquestación de sincronización de índices remotos."""

from __future__ import annotations

from datetime import UTC, datetime
import hashlib
from pathlib import Path

from .index_models import SyncMetadata, SyncResult
from .index_serializers import IndexSerializationError, loads_index
from .index_store import IndexStore, IndexStoreError
from .index_validator import IndexValidationError, validate_index
from .service import RepositoryService, RepositoryServiceError
from .sync_client import SyncClient, SyncClientError


class SyncServiceError(RuntimeError):
    """Error funcional de sincronización."""


def _utc_now() -> str:
    return datetime.now(UTC).isoformat()


class SyncService:
    def __init__(
        self,
        workspace: str | Path,
        *,
        client: SyncClient | None = None,
    ) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.repositories = RepositoryService(self.workspace)
        self.store = IndexStore(self.workspace)
        self.client = client or SyncClient()

    def sync(self, repository_name: str, *, force: bool = False) -> SyncResult:
        try:
            repository = self.repositories.info(repository_name)
        except RepositoryServiceError as exc:
            raise SyncServiceError(str(exc)) from exc
        if not repository.enabled:
            raise SyncServiceError(
                f"El repositorio '{repository.name}' está deshabilitado."
            )

        previous = self.store.load_metadata(repository.name)
        etag = None if force or previous is None else previous.etag
        last_modified = None if force or previous is None else previous.last_modified
        try:
            response = self.client.fetch(
                repository.url,
                etag=etag,
                last_modified=last_modified,
            )
        except SyncClientError as exc:
            raise SyncServiceError(str(exc)) from exc

        if response.status_code == 304:
            if not self.store.exists(repository.name):
                raise SyncServiceError(
                    "El servidor respondió 304 pero no existe un índice local."
                )
            cached = self.store.load_index(repository.name)
            digest = previous.sha256 if previous else self._digest_index(cached)
            return SyncResult(
                repository=repository.name,
                status="unchanged",
                changed=False,
                package_count=len(cached.packages),
                sha256=digest,
                source_url=response.source_url,
                message="El índice remoto no cambió.",
            )

        if response.status_code != 200 or response.content is None:
            raise SyncServiceError(
                f"Respuesta inesperada HTTP {response.status_code}."
            )
        try:
            index = loads_index(response.content)
            validate_index(index, expected_repository=repository.name)
        except (IndexSerializationError, IndexValidationError) as exc:
            raise SyncServiceError(str(exc)) from exc

        normalized = response.content.encode("utf-8")
        digest = hashlib.sha256(normalized).hexdigest()
        unchanged = previous is not None and previous.sha256 == digest and not force
        if unchanged:
            return SyncResult(
                repository=repository.name,
                status="unchanged",
                changed=False,
                package_count=len(index.packages),
                sha256=digest,
                source_url=response.source_url,
                message="El contenido del índice no cambió.",
            )

        metadata = SyncMetadata(
            repository=repository.name,
            source_url=response.source_url,
            synchronized_at=_utc_now(),
            status="updated",
            sha256=digest,
            package_count=len(index.packages),
            etag=response.etag,
            last_modified=response.last_modified,
        )
        self.store.save(repository.name, index, metadata)
        return SyncResult(
            repository=repository.name,
            status="updated",
            changed=True,
            package_count=len(index.packages),
            sha256=digest,
            source_url=response.source_url,
            message="Índice actualizado correctamente.",
        )

    def sync_all(self, *, force: bool = False) -> tuple[SyncResult, ...]:
        repositories = self.repositories.list(enabled_only=True)
        if not repositories:
            raise SyncServiceError("No hay repositorios habilitados.")
        results: list[SyncResult] = []
        errors: list[str] = []
        for repository in repositories:
            try:
                results.append(self.sync(repository.name, force=force))
            except SyncServiceError as exc:
                errors.append(f"{repository.name}: {exc}")
        if errors:
            raise SyncServiceError("; ".join(errors))
        return tuple(results)

    def verify(self, repository_name: str) -> dict[str, object]:
        try:
            index = self.store.load_index(repository_name)
            validate_index(index, expected_repository=repository_name)
        except (IndexValidationError, IndexStoreError, IndexSerializationError) as exc:
            return {
                "repository": repository_name,
                "valid": False,
                "errors": [str(exc)],
                "packages": 0,
            }
        return {
            "repository": repository_name,
            "valid": True,
            "errors": [],
            "packages": len(index.packages),
        }

    @staticmethod
    def _digest_index(index) -> str:
        from .index_serializers import dumps_index
        return hashlib.sha256(dumps_index(index).encode("utf-8")).hexdigest()
