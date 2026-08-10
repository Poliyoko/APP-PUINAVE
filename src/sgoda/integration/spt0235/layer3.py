from __future__ import annotations

from pathlib import Path
from typing import Any

from .catalog import PublishedObjectCatalog
from .manifest import build_publication_manifest
from .publication import review_for_publication
from .references import validate_object_references
from .registry import FldOdaRegistry


class Spt0235Layer3GovernanceService:
    """Gobernanza de publicaciÃ³n y cierre institucional de SPT-023.5."""

    def __init__(
        self,
        *,
        registry_path: str | Path,
        published_catalog_path: str | Path,
    ) -> None:
        self.registry = FldOdaRegistry(registry_path)
        self.catalog = PublishedObjectCatalog(published_catalog_path)

    def review_and_publish(
        self,
        *,
        lexical_id: str,
        reviewer: str,
        reason: str,
        approve: bool,
        version: int | None = None,
        require_multimedia_files: bool = False,
    ) -> dict[str, Any]:
        stored = self.registry.get(lexical_id, version=version)
        if stored is None:
            raise ValueError("Requested FLD/ODA object version was not found.")

        fld = dict(stored["fld"])
        oda = dict(stored["oda"])
        reference_validation = validate_object_references(
            fld,
            oda,
            require_files=require_multimedia_files,
        )

        decision = review_for_publication(
            stored,
            lexical_id=lexical_id,
            approve=approve,
            reviewer=reviewer,
            reason=reason,
        ).to_dict()

        if not decision["approved"]:
            return {
                "component": "SPT-023.5",
                "layer": "3",
                "status": "PUBLICATION_REJECTED",
                "lexical_id": lexical_id,
                "decision": decision,
                "reference_validation": reference_validation,
                "publication_manifest": None,
                "published_record": None,
                "spt0235_scope_complete": False,
                "next_component": "SPT-023.5-CAPA-3",
            }

        manifest = build_publication_manifest(
            decision=decision,
            registry_validation=reference_validation,
        )
        published = self.catalog.publish(manifest)

        return {
            "component": "SPT-023.5",
            "layer": "3",
            "status": "PUBLISHED_FLD_ODA",
            "lexical_id": lexical_id,
            "decision": decision,
            "reference_validation": reference_validation,
            "publication_manifest": manifest,
            "published_record": published,
            "spt0235_scope_complete": True,
            "paid_api_used": False,
            "next_component": "SPT-023.6",
        }
