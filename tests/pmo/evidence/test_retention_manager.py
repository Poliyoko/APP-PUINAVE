from datetime import datetime, timedelta, timezone
from pathlib import Path
import json
from sgoda.pmo.evidence.manager import EvidenceManager
from sgoda.pmo.evidence.models import EvidenceType
from sgoda.pmo.evidence.retention import RetentionDecisionEngine
from sgoda.pmo.evidence.retention_policy import RetentionPolicyRepository

def write_policies(path:Path)->None:
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps({
        "policies":[
            {"policy_id":"RET-MANIFEST","version":"1.0","duration_days":None,
             "action_on_expiry":"keep","permanent":True,"priority":1,
             "match":{"evidence_type":["manifest"]}},
            {"policy_id":"RET-DEFAULT-REVIEW","version":"1.0","duration_days":30,
             "action_on_expiry":"review","permanent":False,"priority":999,"match":{}}
        ]
    }),encoding="utf-8")

def make_manager(tmp_path:Path)->EvidenceManager:
    repo=tmp_path/"repo"
    repo.mkdir()
    write_policies(repo/"config"/"evidence-retention-policies.json")
    return EvidenceManager(repo)

def test_manifest_gets_permanent_policy(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"manifest.json"
    sample.write_text("{}",encoding="utf-8")
    manager.register(sample,evidence_id="EVD-RET-1",evidence_type=EvidenceType.MANIFEST)
    decision=manager.retention.evaluate_one("EVD-RET-1")
    assert decision.policy_id=="RET-MANIFEST"
    assert decision.permanent is True
    assert decision.action=="keep"

def test_dry_run_does_not_change_registry(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    manager.register(sample,evidence_id="EVD-RET-2")
    manager.retention.evaluate_one("EVD-RET-2",apply=False)
    assert manager.registry.get("EVD-RET-2").retention_policy==""

def test_apply_persists_decision(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    manager.register(sample,evidence_id="EVD-RET-3")
    manager.retention.evaluate_one("EVD-RET-3",apply=True)
    record=manager.registry.get("EVD-RET-3")
    assert record.retention_policy=="RET-DEFAULT-REVIEW"
    assert record.retention_action=="keep"

def test_expired_record_becomes_review(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    record=manager.register(sample,evidence_id="EVD-RET-4")
    record.registered_at_utc=(datetime.now(timezone.utc)-timedelta(days=40)).isoformat()
    manager.registry.update(record)
    decision=manager.retention.engine.evaluate(
        manager.registry.get("EVD-RET-4"),datetime.now(timezone.utc)
    )
    assert decision.action=="review"
    assert decision.reason=="expired"

def test_legal_hold_overrides_expiry(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    record=manager.register(sample,evidence_id="EVD-RET-5")
    record.legal_hold=True
    manager.registry.update(record)
    decision=manager.retention.evaluate_one("EVD-RET-5")
    assert decision.action=="keep"
    assert decision.legal_hold is True