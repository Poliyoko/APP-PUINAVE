
from __future__ import annotations
import json
from pathlib import Path
import pytest
from sgoda.automation.workflow_registry import *

def workflow(workflow_id: str, name: str, *, version: str="1.0.0", status: str="validated", category: str="governance") -> dict:
    return {
        "name":name,
        "nodes":[{"id":"trigger-1","name":"Webhook","type":"n8n-nodes-base.webhook","typeVersion":2,"position":[0,0],"parameters":{}}],
        "connections":{},
        "active":False,
        "meta":{"workflow_id":workflow_id,"version":version,"status":status,"category":category,"dependencies":["POL-001"]},
    }

def write_workflow(path: Path, payload: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path

def test_hash_deterministic():
    assert sha256_payload({"b":2,"a":1}) == sha256_payload({"a":1,"b":2})

def test_discovery_sorted(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"b.json",workflow("SPT-019-WF-002","SPT-019 — B"))
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    assert [p.name for p in discover_workflows(root)] == ["a.json","b.json"]

def test_valid_entry(tmp_path):
    root=tmp_path/"workflows"; path=write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    assert entry_from_workflow(path, relative_to=tmp_path).workflow_id == "SPT-019-WF-001"

def test_invalid_entry(tmp_path):
    root=tmp_path/"workflows"; path=write_workflow(root/"a.json",workflow("BAD","SPT-019 — A"))
    with pytest.raises(ValueError): entry_from_workflow(path, relative_to=tmp_path)

def test_build_approved(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(root/"b.json",workflow("SPT-019-WF-002","SPT-019 — B"))
    r=build_registry(root)
    assert r["approved"] and r["workflow_count"] == 2

def test_duplicate_ids_rejected(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(root/"b.json",workflow("SPT-019-WF-001","SPT-019 — B"))
    assert not build_registry(root)["approved"]

def test_query_category(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A",category="governance"))
    write_workflow(root/"b.json",workflow("SPT-019-WF-002","SPT-019 — B",category="pmo"))
    assert query_registry(build_registry(root),category="pmo")[0]["workflow_id"] == "SPT-019-WF-002"

def test_query_status(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A",status="released"))
    assert len(query_registry(build_registry(root),status="released")) == 1

def test_retire(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    updated=retire_workflow(build_registry(root),"SPT-019-WF-001")
    assert updated["workflows"][0]["status"] == "retired"

def test_retire_unknown(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    with pytest.raises(KeyError): retire_workflow(build_registry(root),"SPT-019-WF-999")

def test_compare_added(tmp_path):
    a=tmp_path/"a"; b=tmp_path/"b"
    write_workflow(a/"x.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(b/"x.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(b/"y.json",workflow("SPT-019-WF-002","SPT-019 — B"))
    assert compare_registries(build_registry(a),build_registry(b))["added"] == ["SPT-019-WF-002"]

def test_compare_changed(tmp_path):
    a=tmp_path/"a"; b=tmp_path/"b"
    write_workflow(a/"x.json",workflow("SPT-019-WF-001","SPT-019 — A",status="validated"))
    write_workflow(b/"x.json",workflow("SPT-019-WF-001","SPT-019 — A",status="released"))
    assert compare_registries(build_registry(a),build_registry(b))["changed"] == ["SPT-019-WF-001"]

def test_write_load(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    p=tmp_path/"registry.json"; write_json(p,build_registry(root))
    assert load_registry(p)["component"] == "SPT-019.2"
