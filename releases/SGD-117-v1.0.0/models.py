
from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class RepositoryAsset:
    path: str
    category: str
    size_bytes: int
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class MasterDocumentAudit:
    index_exists: bool
    registry_exists: bool
    index_mentions_component: bool
    registry_mentions_component: bool
    config_declares_component: bool
    release_exists: bool

    @property
    def component_preexisted(self) -> bool:
        return any(
            (
                self.index_mentions_component,
                self.registry_mentions_component,
                self.config_declares_component,
                self.release_exists,
            )
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["component_preexisted"] = self.component_preexisted
        return payload
