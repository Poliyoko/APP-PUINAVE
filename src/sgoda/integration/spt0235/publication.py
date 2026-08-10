from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class PublicationDecision:
    lexical_id: str
    version: int
    status: str
    approved: bool
    reviewer: str
    reason: str
    fld_sha256: str
    oda_sha256: str
    version_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "version": self.version,
            "status": self.status,
            "approved": self.approved,
            "reviewer": self.reviewer,
            "reason": self.reason,
            "fld_sha256": self.fld_sha256,
            "oda_sha256": self.oda_sha256,
            "version_sha256": self.version_sha256,
        }


def review_for_publication(
    stored_version: dict[str, Any],
    *,
    lexical_id: str,
    approve: bool,
    reviewer: str,
    reason: str,
) -> PublicationDecision:
    lexical_id = str(lexical_id or "").strip()
    reviewer = str(reviewer or "").strip()
    reason = str(reason or "").strip()

    if not lexical_id:
        raise ValueError("lexical_id is required.")
    if not reviewer:
        raise ValueError("Human reviewer is required.")
    if not reason:
        raise ValueError("Publication decision reason is required.")

    version = int(stored_version.get("version", 0))
    if version < 1:
        raise ValueError("Stored FLD/ODA version is invalid.")

    fld = dict(stored_version.get("fld") or {})
    oda = dict(stored_version.get("oda") or {})
    version_sha256 = str(stored_version.get("version_sha256") or "").strip()

    if fld.get("object_type") != "FLD":
        raise ValueError("Stored FLD is invalid.")
    if oda.get("object_type") != "ODA":
        raise ValueError("Stored ODA is invalid.")
    if str(fld.get("lexical_id") or "") != lexical_id:
        raise ValueError("FLD lexical_id mismatch.")
    if str(oda.get("lexical_id") or "") != lexical_id:
        raise ValueError("ODA lexical_id mismatch.")
    if str(oda.get("source_fld_sha256") or "") != str(fld.get("fld_sha256") or ""):
        raise ValueError("ODA does not reference the stored FLD hash.")
    if not version_sha256:
        raise ValueError("Stored version SHA-256 is required.")

    return PublicationDecision(
        lexical_id=lexical_id,
        version=version,
        status="APPROVED_FOR_PUBLICATION" if approve else "PUBLICATION_REJECTED",
        approved=bool(approve),
        reviewer=reviewer,
        reason=reason,
        fld_sha256=str(fld["fld_sha256"]),
        oda_sha256=str(oda["oda_sha256"]),
        version_sha256=version_sha256,
    )
