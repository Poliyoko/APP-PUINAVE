from __future__ import annotations

from typing import Any

from .fld import build_fld
from .models import parse_ready_for_fld_oda
from .oda import build_oda


class Spt0235Layer1Service:
    """Constructor determinÃ­stico FLD/ODA desde el handoff de SPT-023.4."""

    def build_one(
        self,
        handoff: dict[str, Any],
        *,
        translations: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        payload = dict(handoff)
        payload["translations"] = dict(translations or payload.get("translations") or {})

        source = parse_ready_for_fld_oda(payload)
        fld = build_fld(source)
        oda = build_oda(fld)

        return {
            "component": "SPT-023.5",
            "layer": "1",
            "status": "FLD_ODA_BUILT",
            "lexical_id": source.lexical_id,
            "fld": fld,
            "oda": oda,
            "traceability": {
                "source_multimedia_manifest_sha256": source.multimedia_manifest_sha256,
                "fld_sha256": fld["fld_sha256"],
                "oda_sha256": oda["oda_sha256"],
            },
            "next_component": "SPT-023.5-CAPA-2",
        }

    def build_batch(
        self,
        handoffs: list[dict[str, Any]],
        *,
        translations_by_lexical_id: dict[str, dict[str, str]] | None = None,
    ) -> dict[str, Any]:
        translations_by_lexical_id = translations_by_lexical_id or {}
        results = []

        for handoff in handoffs:
            lexical_id = str(handoff.get("lexical_id") or "").strip()
            results.append(
                self.build_one(
                    handoff,
                    translations=translations_by_lexical_id.get(lexical_id, {}),
                )
            )

        return {
            "component": "SPT-023.5",
            "layer": "1",
            "records_processed": len(results),
            "fld_built": len(results),
            "oda_built": len(results),
            "results": results,
            "next_component": "SPT-023.5-CAPA-2",
        }
