"""Gestión de repositorios remotos SGODA."""

from .models import Repository, RepositoryRegistry
from .serializers import (
    RepositorySerializationError,
    dumps_registry,
    loads_registry,
)
from .service import RepositoryService, RepositoryServiceError
from .store import RepositoryStore, RepositoryStoreError
from .validator import (
    RepositoryValidationError,
    normalize_name,
    normalize_url,
    validate_priority,
)

__all__ = [
    "Repository",
    "RepositoryRegistry",
    "RepositorySerializationError",
    "RepositoryService",
    "RepositoryServiceError",
    "RepositoryStore",
    "RepositoryStoreError",
    "RepositoryValidationError",
    "dumps_registry",
    "loads_registry",
    "normalize_name",
    "normalize_url",
    "validate_priority",
]


from .index_models import IndexPackage, RepositoryIndex, SyncMetadata, SyncResult
from .index_serializers import IndexSerializationError, dumps_index, loads_index
from .index_store import IndexStore, IndexStoreError
from .index_validator import IndexValidationError, validate_index
from .sync_client import SyncClient, SyncClientError, SyncResponse
from .sync_service import SyncService, SyncServiceError

__all__ += [
    "IndexPackage",
    "RepositoryIndex",
    "SyncMetadata",
    "SyncResult",
    "IndexSerializationError",
    "IndexStore",
    "IndexStoreError",
    "IndexValidationError",
    "SyncClient",
    "SyncClientError",
    "SyncResponse",
    "SyncService",
    "SyncServiceError",
    "dumps_index",
    "loads_index",
    "validate_index",
]
