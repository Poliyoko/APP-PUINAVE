from __future__ import annotations

import hashlib
import json
from typing import Any, Iterable

from .models import MultimediaPlan, MultimediaResourcePlan
from .policy import ROUTES, validate_policy


def _stable_id(lexical_id: str, resource_type: str, language: str | None) -> str:
    canonical = json.dumps(
        {
            "lexical_id": lexical_id,
            "resource_type": resource_type,
            "language": language,
        },
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    digest = hashlib.sha256(canonical).hexdigest()[:16].upper()
    return f"MM-{digest}"


def _existing_types(existing_resources: Iterable[dict[str, Any]] | None) -> set[str]:
    found: set[str] = set()
    for item in existing_resources or ():
        if not isinstance(item, dict):
            continue
        resource_type = str(item.get("resource_type") or "").strip()
        status = str(item.get("status") or "").strip().upper()
        if resource_type and status in {"READY", "VALID", "APPROVED", "PUBLISHED"}:
            found.add(resource_type)
    return found


def build_multimedia_plan(
    record: dict[str, Any],
    *,
    existing_resources: Iterable[dict[str, Any]] | None = None,
) -> MultimediaPlan:
    validate_policy()

    lexical_id = str(
        record.get("canonical_id")
        or record.get("lexical_id")
        or record.get("lexical_hash")
        or ""
    ).strip()
    puinave = str(record.get("puinave") or "").strip()
    category_id = str(
        record.get("selected_category_id")
        or record.get("principal_category_id")
        or record.get("category_id")
        or ""
    ).strip() or None

    if not lexical_id:
        raise ValueError("A stable lexical identifier is required.")
    if not puinave:
        raise ValueError("Puinave text is required.")

    existing = _existing_types(existing_resources)
    plans: list[MultimediaResourcePlan] = []

    for route in ROUTES:
        reused = route.resource_type in existing

        if reused:
            status = "REUSE_EXISTING"
        elif route.resource_type == "audio_puinave":
            status = "NATIVE_RECORDING_REQUIRED"
        elif route.resource_type == "image":
            status = "READY_FOR_LOCAL_IMAGE"
        else:
            status = "READY_FOR_LOCAL_TTS"

        metadata = {
            "source_component": "SPT-023.3",
            "target_component": "SPT-023.4",
            "legacy_components_reused": [
                "SPT-003A",
                "SPT-003B",
                "SPT-006",
                "SPT-006A",
                "ADR-010",
            ],
            "no_paid_api": True,
            "no_external_call_in_layer1": True,
        }

        plans.append(
            MultimediaResourcePlan(
                resource_id=_stable_id(
                    lexical_id,
                    route.resource_type,
                    route.language,
                ),
                lexical_id=lexical_id,
                resource_type=route.resource_type,
                language=route.language,
                route=route.route,
                provider_family=route.provider_family,
                status=status,
                required=True,
                requires_human_validation=route.requires_human_validation,
                existing_resource_reused=reused,
                metadata=metadata,
            )
        )

    return MultimediaPlan(
        lexical_id=lexical_id,
        puinave=puinave,
        category_id=category_id,
        plans=tuple(plans),
    )
