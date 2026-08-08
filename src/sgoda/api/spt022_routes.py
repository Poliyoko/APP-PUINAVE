"""API local SPT-022 para orquestacion n8n."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict

from fastapi import APIRouter, HTTPException, Request

from sgoda.automation.spt022.executor import InstitutionalExecutor
from sgoda.automation.spt022.platform import AutomationPlatform

router = APIRouter(prefix="/api/spt022", tags=["SPT-022"])


def _root() -> Path:
    value = os.environ.get("SGODA_PROJECT_ROOT")
    if value:
        return Path(value).resolve()
    return Path.cwd().resolve()


def _local_only(request: Request) -> None:
    client = request.client
    host = client.host if client else ""
    if host not in {"127.0.0.1", "::1", "localhost", "testclient"}:
        raise HTTPException(status_code=403, detail="Local access only")


@router.get("/health")
def health(request: Request) -> Dict[str, Any]:
    _local_only(request)
    platform = AutomationPlatform(_root())
    return {
        "component": "SPT-022",
        "status": "OPERATIONAL",
        "orchestrator": "n8n",
        "operations": len(platform.list()),
        "path_validation": platform.validate_paths(),
    }


@router.get("/catalog")
def catalog(request: Request) -> Dict[str, Any]:
    _local_only(request)
    platform = AutomationPlatform(_root())
    return {"operations": platform.as_dicts()}


@router.post("/run/{operation_id}")
def run_operation(
    operation_id: str,
    request: Request,
    payload: Dict[str, Any] | None = None,
) -> Dict[str, Any]:
    _local_only(request)
    platform = AutomationPlatform(_root())
    try:
        platform.get(operation_id)
    except KeyError as exc:
        raise HTTPException(
            status_code=404,
            detail="Unknown operation",
        ) from exc

    executor = InstitutionalExecutor(_root())
    return executor.execute(operation_id, payload or {})