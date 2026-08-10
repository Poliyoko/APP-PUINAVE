from __future__ import annotations

import hashlib
import json
from typing import Any

from .contracts import PIPELINE, validate_pipeline_contract
from .models import OrchestrationPlan


def _orchestration_id(lexical_id: str) -> str:
    digest = hashlib.sha256(
        json.dumps(
            {"lexical_id": lexical_id, "pipeline": "SPT-023.6"},
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()[:20].upper()
    return f"ORCH-{digest}"


def build_orchestration_plan(
    *,
    lexical_id: str,
    current_status: str = "NEW",
) -> OrchestrationPlan:
    validate_pipeline_contract()

    lexical_id = str(lexical_id or "").strip()
    current_status = str(current_status or "").strip() or "NEW"

    if not lexical_id:
        raise ValueError("lexical_id is required.")

    return OrchestrationPlan(
        orchestration_id=_orchestration_id(lexical_id),
        lexical_id=lexical_id,
        current_status=current_status,
        steps=PIPELINE,
        next_component="SPT-023.6-CAPA-2",
    )
