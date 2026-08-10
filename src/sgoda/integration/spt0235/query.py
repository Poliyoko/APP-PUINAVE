from __future__ import annotations

from typing import Any

from .registry import FldOdaRegistry


class FldOdaQueryService:
    def __init__(self, registry: FldOdaRegistry) -> None:
        self.registry = registry

    def by_lexical_id(
        self,
        lexical_id: str,
        *,
        version: int | None = None,
    ) -> dict[str, Any] | None:
        result = self.registry.get(lexical_id, version=version)
        if result is None:
            return None

        return {
            "component": "SPT-023.5",
            "layer": "2",
            "lexical_id": lexical_id,
            "version": result["version"],
            "fld": result["fld"],
            "oda": result["oda"],
            "version_sha256": result["version_sha256"],
        }
