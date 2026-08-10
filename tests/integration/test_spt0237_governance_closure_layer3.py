from pathlib import Path

import pytest

from sgoda.integration.spt0237.closure import Spt0237ClosureManifestBuilder
from sgoda.integration.spt0237.gates import (
    InstitutionalQualityGateEngine,
    QualityGate,
)
from sgoda.integration.spt0237.governance import ClosureGovernancePolicy
from sgoda.integration.spt0237.layer3 import Spt0237Layer3ClosureService
from sgoda.integration.spt0237.ledger import InstitutionalAuditLedger


def make_component(root: Path, number: int):
    base = root / "src" / "sgoda" / "integration" / f"spt023{number}"
    base.mkdir(parents=True, exist_ok=True)
    (base / "service.py").write_text("VALUE = 1\n", encoding="utf-8")

    tests = root / "tests" / "integration"
    tests.mkdir(parents=True, exist_ok=True)
    (tests / f"test_spt023{number}.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )

    docs = root / "docs" / f"SPT-023.{number}"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / f"SGD-SPT023.{number}.md").write_text("# doc\n", encoding="utf-8")

    evidence = root / "artifacts" / "development" / f"SPT-023.{number}"
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "implementation-evidence.json").write_text(
        '{"ok": true}\n',
        encoding="utf-8",
    )


def make_repo(root: Path):
    for number in range(1, 7):
        make_component(root, number)


def clean_layer2_result():
    return {
        "layer": "2",
        "layer1_reused": True,
        "paid_api_used": False,
        "correlations": [],
        "risk": {
            "score": 0,
            "level": "NONE",
            "blocking_findings": 0,
            "correlated_groups": 0,
        },
        "evidence_bundle": {
            "sha256": "A" * 64,
            "finding_count": 0,
        },
        "cross_component_inconsistencies": [],
        "verdict": {
            "status": "INSTITUTIONAL_AUDIT_APPROVED",
            "publishable": True,
            "blocking_reasons": [],
        },
    }


def test_quality_gate_serializes():
    gate = QualityGate("G", "Gate", True, True, "ok")
    assert gate.to_dict()["passed"] is True


def test_gate_engine_builds_seven_required_gates():
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=clean_layer2_result(),
        protected_changes=0,
    )
    assert len(gates) == 7


def test_gate_engine_certificate_passes_clean_result():
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=clean_layer2_result(),
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is True


def test_gate_engine_fails_high_risk():
    result = clean_layer2_result()
    result["risk"]["level"] = "HIGH"
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    certificate = InstitutionalQualityGateEngine.certify(gates)
    assert certificate["passed"] is False
    assert "GATE-RISK" in certificate["failed_blocking"]


def test_gate_engine_fails_invalid_evidence():
    result = clean_layer2_result()
    result["evidence_bundle"]["sha256"] = "BAD"
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_gate_engine_fails_protected_changes():
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=clean_layer2_result(),
        protected_changes=1,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_gate_engine_fails_blocking_cross_component():
    result = clean_layer2_result()
    result["cross_component_inconsistencies"] = [
        {"severity": "ERROR", "code": "X"}
    ]
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_gate_engine_fails_nonapproved_verdict():
    result = clean_layer2_result()
    result["verdict"]["status"] = "INSTITUTIONAL_AUDIT_HOLD"
    result["verdict"]["publishable"] = False
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_governance_passes_clean_result():
    result = clean_layer2_result()
    cert = InstitutionalQualityGateEngine.certify(
        InstitutionalQualityGateEngine.build(
            layer2_result=result,
            protected_changes=0,
        )
    )
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate=cert,
        protected_changes=0,
    )
    assert governance["passed"] is True


def test_governance_fails_without_layer1_reuse():
    result = clean_layer2_result()
    result["layer1_reused"] = False
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate={"passed": True},
        protected_changes=0,
    )
    assert "LAYER1_NOT_REUSED" in governance["violations"]


def test_governance_fails_paid_api():
    result = clean_layer2_result()
    result["paid_api_used"] = True
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate={"passed": True},
        protected_changes=0,
    )
    assert "PAID_API_USAGE_DETECTED" in governance["violations"]


def test_governance_fails_invalid_sha():
    result = clean_layer2_result()
    result["evidence_bundle"]["sha256"] = "BAD"
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate={"passed": True},
        protected_changes=0,
    )
    assert "EVIDENCE_SHA256_INVALID" in governance["violations"]


def test_ledger_appends_and_verifies(tmp_path):
    ledger = InstitutionalAuditLedger(tmp_path / "ledger.json")
    ledger.append(event_type="X", payload={"a": 1})
    assert InstitutionalAuditLedger.verify(ledger.all()) is True


def test_ledger_hash_chain(tmp_path):
    ledger = InstitutionalAuditLedger(tmp_path / "ledger.json")
    first = ledger.append(event_type="A", payload={})
    second = ledger.append(event_type="B", payload={})
    assert second["previous_hash"] == first["entry_sha256"]


def test_ledger_detects_tampering(tmp_path):
    ledger = InstitutionalAuditLedger(tmp_path / "ledger.json")
    item = ledger.append(event_type="A", payload={})
    item["entry_sha256"] = "BAD"
    with pytest.raises(ValueError):
        InstitutionalAuditLedger.verify([item])


def test_closure_manifest_requires_quality_gates():
    with pytest.raises(ValueError):
        Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=False,
            governance_passed=True,
            protected_changes=0,
        )


def test_closure_manifest_requires_governance():
    with pytest.raises(ValueError):
        Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=True,
            governance_passed=False,
            protected_changes=0,
        )


def test_closure_manifest_requires_preservation():
    with pytest.raises(ValueError):
        Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=True,
            governance_passed=True,
            protected_changes=1,
        )


def test_closure_manifest_is_closed_when_valid():
    manifest = Spt0237ClosureManifestBuilder.build(
        quality_gates_passed=True,
        governance_passed=True,
        protected_changes=0,
    )
    assert manifest.status == "INSTITUTIONALLY_CLOSED"


def test_closure_manifest_sha_is_64_chars():
    manifest = Spt0237ClosureManifestBuilder.build(
        quality_gates_passed=True,
        governance_passed=True,
        protected_changes=0,
    )
    assert len(manifest.manifest_sha256) == 64


def test_closure_manifest_points_to_spt0238():
    manifest = Spt0237ClosureManifestBuilder.build(
        quality_gates_passed=True,
        governance_passed=True,
        protected_changes=0,
    )
    assert manifest.next_component == "SPT-023.8"


def test_layer3_clean_fixture_closes(tmp_path):
    make_repo(tmp_path)
    service = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    )
    result = service.evaluate(protected_changes=0)
    assert result["status"] == "INSTITUTIONALLY_CLOSED"


def test_layer3_quality_gates_pass(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["quality_gate_certificate"]["passed"] is True


def test_layer3_governance_passes(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["governance"]["passed"] is True


def test_layer3_ledger_verified(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["ledger_verified"] is True


def test_layer3_preserves_layer1_and_layer2(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["layer1_preserved"] is True
    assert result["layer2_preserved"] is True


def test_layer3_disables_paid_api(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["paid_api_used"] is False


def test_layer3_does_not_mutate_closed_components(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["closed_components_mutated"] is False


def test_layer3_points_to_spt0238(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["next_component"] == "SPT-023.8"
