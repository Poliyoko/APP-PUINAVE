from __future__ import annotations

from dataclasses import dataclass
from typing import Any


REQUIRED_RESOURCE_TYPES = (
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "audio_it",
)


@dataclass(frozen=True)
class ResourceQualityDecision:
    resource_id: str
    resource_type: str
    status: str
    approved: bool
    reviewer: str | None
    reason: str | None
    sha256: str
    output_path: str
    validation: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "resource_id": self.resource_id,
            "resource_type": self.resource_type,
            "status": self.status,
            "approved": self.approved,
            "reviewer": self.reviewer,
            "reason": self.reason,
            "sha256": self.sha256,
            "output_path": self.output_path,
            "validation": dict(self.validation),
        }


def validate_resource_record(record: dict[str, Any]) -> None:
    required = (
        "resource_id",
        "resource_type",
        "status",
        "sha256",
        "output_path",
        "validation",
    )
    missing = [key for key in required if key not in record]
    if missing:
        raise ValueError(f"Resource record missing fields: {missing}")

    resource_type = str(record["resource_type"])
    if resource_type not in REQUIRED_RESOURCE_TYPES:
        raise ValueError(f"Unsupported resource_type: {resource_type}")

    if not str(record["sha256"]).strip():
        raise ValueError("Resource SHA-256 is required.")

    if not bool((record.get("validation") or {}).get("valid")):
        raise ValueError("Resource validation must be valid before quality review.")


def review_resource(
    record: dict[str, Any],
    *,
    approve: bool,
    reviewer: str,
    reason: str,
) -> ResourceQualityDecision:
    validate_resource_record(record)

    reviewer = str(reviewer or "").strip()
    reason = str(reason or "").strip()

    if not reviewer:
        raise ValueError("Human reviewer is required.")
    if not reason:
        raise ValueError("Quality decision reason is required.")

    return ResourceQualityDecision(
        resource_id=str(record["resource_id"]),
        resource_type=str(record["resource_type"]),
        status="APPROVED" if approve else "REJECTED",
        approved=bool(approve),
        reviewer=reviewer,
        reason=reason,
        sha256=str(record["sha256"]),
        output_path=str(record["output_path"]),
        validation=dict(record["validation"]),
    )
