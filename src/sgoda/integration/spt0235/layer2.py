from __future__ import annotations

from pathlib import Path
from typing import Any

from .query import FldOdaQueryService
from .references import validate_object_references
from .registry import FldOdaRegistry


class Spt0235Layer2Service:
    """Persistencia, versionado, validaciÃ³n y consulta de FLD/ODA."""

    def __init__(self, registry_path: str | Path) -> None:
        self.registry = FldOdaRegistry(registry_path)
        self.query = FldOdaQueryService(self.registry)

    def persist(
        self,
        build_result: dict[str, Any],
        *,
        require_multimedia_files: bool = False,
    ) -> dict[str, Any]:
        if str(build_result.get("status") or "") != "FLD_ODA_BUILT":
            raise ValueError("SPT-023.5 Capa 2 requires FLD_ODA_BUILT input.")

        lexical_id = str(build_result.get("lexical_id") or "").strip()
        fld = dict(build_result.get("fld") or {})
        oda = dict(build_result.get("oda") or {})

        validation = validate_object_references(
            fld,
            oda,
            require_files=require_multimedia_files,
        )

        stored = self.registry.save_entry(
            lexical_id=lexical_id,
            fld=fld,
            oda=oda,
        )

        return {
            "component": "SPT-023.5",
            "layer": "2",
            "status": "FLD_ODA_PERSISTED",
            "lexical_id": lexical_id,
            "version": stored["version"],
            "version_sha256": stored["version_sha256"],
            "reference_validation": validation,
            "registry_verified": True,
            "next_component": "SPT-023.5-CAPA-3",
        }

    def retrieve(
        self,
        lexical_id: str,
        *,
        version: int | None = None,
    ) -> dict[str, Any] | None:
        return self.query.by_lexical_id(
            lexical_id,
            version=version,
        )
