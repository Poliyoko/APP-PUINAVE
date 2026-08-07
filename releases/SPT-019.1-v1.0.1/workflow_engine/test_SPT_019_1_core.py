
from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.automation.workflow_engine import (
    build_registry,
    canonical_json,
    load_workflow,
    sha256_payload,
    simulate_workflow,
    validate_workflow,
)


def workflow(
    *,
    workflow_id: str = "SPT-019-WF-001",
    name: str = "SPT-019 — Workflow de prueba",
    category: str = "governance",
    status: str = "draft",
    active: bool = False,
) -> dict:
    return {
        "name": name,
        "nodes": [
            {
                "id": "trigger-1",
                "name": "Webhook",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2,
                "position": [0, 0],
                "parameters": {
                    "httpMethod": "POST",
                    "path": "test",
                },
            },
            {
                "id": "set-1",
                "name": "Normalizar",
                "type": "n8n-nodes-base.set",
                "typeVersion": 3,
                "position": [240, 0],
                "parameters": {},
            },
        ],
        "connections": {
            "Webhook": {
                "main": [[{"node": "Normalizar", "type": "main", "index": 0}]]
            }
        },
        "active": active,
        "settings": {"executionOrder": "v1"},
        "meta": {
            "workflow_id": workflow_id,
            "version": "0.1.0",
            "status": status,
            "category": category,
            "dependencies": ["POL-001"],
        },
    }


def write(path: Path, payload: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return path


def test_load_workflow(tmp_path: Path) -> None:
    path = write(tmp_path / "workflow.json", workflow())
    assert load_workflow(path)["name"].startswith("SPT-019")


def test_valid_workflow_is_approved(tmp_path: Path) -> None:
    result = validate_workflow(write(tmp_path / "workflow.json", workflow()))
    assert result.approved
    assert result.record is not None


def test_invalid_json_is_rejected(tmp_path: Path) -> None:
    path = tmp_path / "workflow.json"
    path.write_text("{", encoding="utf-8")
    assert not validate_workflow(path).approved


def test_missing_trigger_is_rejected(tmp_path: Path) -> None:
    payload = workflow()
    payload["nodes"][0]["type"] = "n8n-nodes-base.set"
    assert not validate_workflow(write(tmp_path / "workflow.json", payload)).approved


def test_duplicate_node_id_is_rejected(tmp_path: Path) -> None:
    payload = workflow()
    payload["nodes"][1]["id"] = "trigger-1"
    assert not validate_workflow(write(tmp_path / "workflow.json", payload)).approved


def test_invalid_category_is_rejected(tmp_path: Path) -> None:
    payload = workflow(category="unknown")
    assert not validate_workflow(write(tmp_path / "workflow.json", payload)).approved


def test_active_workflow_generates_warning(tmp_path: Path) -> None:
    result = validate_workflow(
        write(tmp_path / "workflow.json", workflow(active=True))
    )
    assert result.approved
    assert result.warnings


def test_hash_is_deterministic() -> None:
    assert sha256_payload({"b": 2, "a": 1}) == sha256_payload({"a": 1, "b": 2})
    assert canonical_json({"b": 2, "a": 1}) == canonical_json({"a": 1, "b": 2})


def test_registry_is_sorted_and_approved(tmp_path: Path) -> None:
    workflows_dir = tmp_path / "workflows"
    first = write(
        workflows_dir / "b.json",
        workflow(workflow_id="SPT-019-WF-002", name="SPT-019 — B"),
    )
    second = write(
        workflows_dir / "a.json",
        workflow(workflow_id="SPT-019-WF-001", name="SPT-019 — A"),
    )
    registry = build_registry([first, second], relative_to=tmp_path)
    assert registry["approved"]
    assert [item["workflow_id"] for item in registry["workflows"]] == [
        "SPT-019-WF-001",
        "SPT-019-WF-002",
    ]


def test_registry_rejects_duplicate_ids(tmp_path: Path) -> None:
    workflows_dir = tmp_path / "workflows"
    first = write(workflows_dir / "a.json", workflow(name="SPT-019 — A"))
    second = write(workflows_dir / "b.json", workflow(name="SPT-019 — B"))
    registry = build_registry([first, second], relative_to=tmp_path)
    assert not registry["approved"]


def test_simulator_does_not_execute_external_actions(tmp_path: Path) -> None:
    path = write(tmp_path / "workflow.json", workflow())
    result = simulate_workflow(path, {"event": "test"})
    assert result["simulation"] is True
    assert result["executed"] is False



def test_load_event_file_accepts_object(tmp_path: Path) -> None:
    from sgoda.automation.workflow_engine import load_event_file

    path = tmp_path / "event.json"
    path.write_text('{"event":"policy.audit.requested"}', encoding="utf-8")
    assert load_event_file(path)["event"] == "policy.audit.requested"


def test_load_event_file_rejects_array(tmp_path: Path) -> None:
    from sgoda.automation.workflow_engine import load_event_file

    path = tmp_path / "event.json"
    path.write_text('[]', encoding="utf-8")

    with pytest.raises(ValueError):
        load_event_file(path)

def test_simulator_rejects_invalid_workflow(tmp_path: Path) -> None:
    path = write(tmp_path / "workflow.json", workflow(category="invalid"))
    with pytest.raises(ValueError):
        simulate_workflow(path, {"event": "test"})