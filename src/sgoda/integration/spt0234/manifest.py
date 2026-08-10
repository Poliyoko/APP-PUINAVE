from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Iterable

from .quality import REQUIRED_RESOURCE_TYPES


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


@dataclass(frozen=True)
class MultimediaCompletenessManifest:
    lexical_id: str
    complete: bool
    required_resources: tuple[str, ...]
    approved_resources: tuple[str, ...]
    missing_resources: tuple[str, ...]
    rejected_resources: tuple[str, ...]
    manifest_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "complete": self.complete,
            "required_resources": list(self.required_resources),
            "approved_resources": list(self.approved_resources),
            "missing_resources": list(self.missing_resources),
            "rejected_resources": list(self.rejected_resources),
            "manifest_sha256": self.manifest_sha256,
        }


def build_completeness_manifest(
    lexical_id: str,
    decisions: Iterable[dict[str, Any]],
) -> MultimediaCompletenessManifest:
    lexical_id = str(lexical_id or "").strip()
    if not lexical_id:
        raise ValueError("lexical_id is required.")

    by_type: dict[str, dict[str, Any]] = {}
    for raw in decisions:
        resource_type = str(raw.get("resource_type") or "").strip()
        if resource_type not in REQUIRED_RESOURCE_TYPES:
            raise ValueError(f"Unsupported resource_type in decision: {resource_type}")
        if resource_type in by_type:
            raise ValueError(f"Duplicate quality decision for {resource_type}")
        by_type[resource_type] = dict(raw)

    approved = tuple(
        resource_type
        for resource_type in REQUIRED_RESOURCE_TYPES
        if resource_type in by_type and bool(by_type[resource_type].get("approved"))
    )
    rejected = tuple(
        resource_type
        for resource_type in REQUIRED_RESOURCE_TYPES
        if resource_type in by_type and not bool(by_type[resource_type].get("approved"))
    )
    missing = tuple(
        resource_type
        for resource_type in REQUIRED_RESOURCE_TYPES
        if resource_type not in by_type
    )

    complete = not missing and not rejected and len(approved) == len(REQUIRED_RESOURCE_TYPES)

    payload = {
        "lexical_id": lexical_id,
        "required_resources": list(REQUIRED_RESOURCE_TYPES),
        "approved_resources": list(approved),
        "missing_resources": list(missing),
        "rejected_resources": list(rejected),
        "complete": complete,
    }
    digest = hashlib.sha256(_canonical(payload)).hexdigest().upper()

    return MultimediaCompletenessManifest(
        lexical_id=lexical_id,
        complete=complete,
        required_resources=tuple(REQUIRED_RESOURCE_TYPES),
        approved_resources=approved,
        missing_resources=missing,
        rejected_resources=rejected,
        manifest_sha256=digest,
    )
