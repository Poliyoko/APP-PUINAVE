from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class CategoryDecisionTrace:
    decision_id: str
    source_component: str
    target_component: str
    source_index: int
    lexical_hash: str
    status: str
    principal_category_id: str | None
    selected_category_id: str | None
    confidence: float
    proposal_id: str | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "decision_id": self.decision_id,
            "source_component": self.source_component,
            "target_component": self.target_component,
            "source_index": self.source_index,
            "lexical_hash": self.lexical_hash,
            "status": self.status,
            "principal_category_id": self.principal_category_id,
            "selected_category_id": self.selected_category_id,
            "confidence": self.confidence,
            "proposal_id": self.proposal_id,
        }


def build_trace(
    *,
    source_index: int,
    lexical_hash: str,
    status: str,
    principal_category_id: str | None,
    selected_category_id: str | None,
    confidence: float,
    proposal_id: str | None,
) -> CategoryDecisionTrace:
    payload = {
        "source_component": "SPT-023.2",
        "target_component": "SPT-023.3",
        "source_index": int(source_index),
        "lexical_hash": str(lexical_hash or ""),
        "status": status,
        "principal_category_id": principal_category_id,
        "selected_category_id": selected_category_id,
        "confidence": round(float(confidence), 6),
        "proposal_id": proposal_id,
    }
    canonical = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    decision_id = "SPT0233-" + hashlib.sha256(canonical).hexdigest()[:16].upper()

    return CategoryDecisionTrace(
        decision_id=decision_id,
        **payload,
    )
