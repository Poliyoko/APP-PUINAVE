import json
from pathlib import Path

from sgoda.integration.spt0247l3.service import SupplyChainClosureService


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture(tmp_path):
    assessment = "artifacts/l2/assessment.json"
    sbom = "artifacts/l2/sbom.json"
    integrity = "artifacts/l2/integrity.json"
    evidence = "artifacts/l2/evidence.json"

    write_json(tmp_path / assessment, {
        "status": "SUPPLY_CHAIN_LAYER2_GATE_PASS",
        "workflow_executed": False,
        "package_installed": False,
        "release_published": False,
        "secret_values_exposed": False,
    })
    write_json(tmp_path / sbom, {"component_count": 2, "components": []})
    write_json(tmp_path / integrity, {"record_count": 2, "records": []})
    write_json(tmp_path / evidence, {"status": "PASS"})

    return assessment, sbom, integrity, evidence


def test_closure_passes(tmp_path):
    a, s, i, e = fixture(tmp_path)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "INSTITUTIONALLY_CLOSED"
    assert result["failed_blocking_controls"] == []


def test_capa2_hold_blocks(tmp_path):
    a, s, i, e = fixture(tmp_path)
    write_json(tmp_path / a, {
        "status": "SUPPLY_CHAIN_LAYER2_GATE_HOLD",
        "workflow_executed": False,
        "package_installed": False,
        "release_published": False,
        "secret_values_exposed": False,
    })
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-CAPA2-PASS" in result["failed_blocking_controls"]


def test_secret_exposure_blocks(tmp_path):
    a, s, i, e = fixture(tmp_path)
    data = json.loads((tmp_path / a).read_text(encoding="utf-8"))
    data["secret_values_exposed"] = True
    write_json(tmp_path / a, data)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-SECRET-SAFETY" in result["failed_blocking_controls"]


def test_execution_side_effect_blocks(tmp_path):
    a, s, i, e = fixture(tmp_path)
    data = json.loads((tmp_path / a).read_text(encoding="utf-8"))
    data["workflow_executed"] = True
    write_json(tmp_path / a, data)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-PUBLICATION-SAFETY" in result["failed_blocking_controls"]


def test_missing_evidence_is_detected(tmp_path):
    a, s, i, e = fixture(tmp_path)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e, "missing.json"])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-EVIDENCE-INTEGRITY" in result["failed_blocking_controls"]
