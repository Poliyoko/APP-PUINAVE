from __future__ import annotations

import hashlib
import json
import unicodedata
from dataclasses import dataclass
from typing import Iterable


def _normalize(value: object) -> str:
    text = str(value or "").strip()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return text.casefold()


@dataclass(frozen=True)
class CategoryProposal:
    proposal_id: str
    proposed_name: str
    normalized_name: str
    status: str = "PROPOSED_FOR_HUMAN_REVIEW"
    automatic_creation: bool = False
    requires_human_validation: bool = True

    def to_dict(self) -> dict[str, object]:
        return {
            "proposal_id": self.proposal_id,
            "proposed_name": self.proposed_name,
            "normalized_name": self.normalized_name,
            "status": self.status,
            "automatic_creation": self.automatic_creation,
            "requires_human_validation": self.requires_human_validation,
        }


def build_category_proposal(evidence: Iterable[str]) -> CategoryProposal | None:
    candidates = [str(value).strip() for value in evidence if str(value).strip()]
    if not candidates:
        return None

    proposed_name = candidates[0]
    normalized = _normalize(proposed_name)
    if not normalized:
        return None

    canonical = json.dumps(
        {"normalized_name": normalized},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

    proposal_id = "CAT-PROP-" + hashlib.sha256(canonical).hexdigest()[:12].upper()

    return CategoryProposal(
        proposal_id=proposal_id,
        proposed_name=proposed_name,
        normalized_name=normalized,
    )
