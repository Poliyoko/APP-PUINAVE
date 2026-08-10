import json
from pathlib import Path

import pytest

from sgoda.integration.spt0237 import (
    AuditFinding,
    AuditPolicy,
    AuditReport,
    IntelligentAuditor,
    Spt0237Layer1Service,
    TransversalScanner,
)


def make_component(root: Path, number: int):
    base = root / "src" / "sgoda" / "integration" / f"spt023{number}"
    base.mkdir(parents=True, exist_ok=True)
    (base / "service.py").write_text("VALUE = 1\n", encoding="utf-8")
    tests = root / "tests" / "integration"
    tests.mkdir(parents=True, exist_ok=True)
    (tests / f"test_spt023{number}.py").write_text("def test_ok(): assert True\n", encoding="utf-8")
    docs = root / "docs" / f"SPT-023.{number}"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / f"SGD-SPT023.{number}.md").write_text("# doc\n", encoding="utf-8")
    evidence = root / "artifacts" / "development" / f"SPT-023.{number}"
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "implementation-evidence.json").write_text('{"ok": true}\n', encoding="utf-8")


def make_repo(root: Path):
    for number in range(1, 7):
        make_component(root, number)


def test_default_scope_has_six_closed_components():
    assert AuditPolicy.default().scope == tuple(f"SPT-023.{i}" for i in range(1, 7))


def test_default_policy_has_seven_dimensions():
    assert len(AuditPolicy.default().dimensions) == 7


def test_finding_error_is_blocking():
    assert AuditFinding("integrity", "X", "ERROR", "x").blocking


def test_finding_warning_is_not_blocking():
    assert not AuditFinding("quality", "X", "WARNING", "x").blocking


def test_empty_report_is_conformant():
    assert AuditReport(("SPT-023.1",)).conformant


def test_report_with_error_is_not_conformant():
    report = AuditReport(("SPT-023.1",), [AuditFinding("integrity", "X", "ERROR", "x")])
    assert not report.conformant


def test_report_serializes():
    report = AuditReport(("SPT-023.1",))
    assert report.to_dict()["conformant"] is True


def test_scanner_sha256(tmp_path):
    path = tmp_path / "x.txt"
    path.write_text("abc", encoding="utf-8")
    assert len(TransversalScanner.sha256(path)) == 64


def test_scanner_finds_component_files(tmp_path):
    make_component(tmp_path, 1)
    assert TransversalScanner(tmp_path).component_files("SPT-023.1")


def test_inventory_contains_all_requested_keys(tmp_path):
    make_repo(tmp_path)
    inv = TransversalScanner(tmp_path).inventory(AuditPolicy.default().scope)
    assert set(inv) == set(AuditPolicy.default().scope)


def test_complete_fixture_has_no_blocking_findings(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.conformant


def test_missing_component_is_blocking(tmp_path):
    for number in range(1, 6):
        make_component(tmp_path, number)
    report = IntelligentAuditor(tmp_path).run()
    assert any(f.code == "COMPONENT_RESOURCE_MISSING" for f in report.blocking_findings)


def test_empty_component_file_is_blocking(tmp_path):
    make_repo(tmp_path)
    path = tmp_path / "src" / "sgoda" / "integration" / "spt0231" / "empty.py"
    path.write_bytes(b"")
    report = IntelligentAuditor(tmp_path).run()
    assert any(f.code == "EMPTY_FILE" for f in report.blocking_findings)


def test_metrics_report_six_components(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.metrics["components_scanned"] == 6


def test_metrics_report_seven_dimensions(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.metrics["dimensions"] == 7


def test_count_by_dimension(tmp_path):
    report = AuditReport(
        ("SPT-023.1",),
        [
            AuditFinding("quality", "A", "WARNING", "a"),
            AuditFinding("quality", "B", "WARNING", "b"),
        ],
    )
    assert report.count_by_dimension()["quality"] == 2


def test_service_runs(tmp_path):
    make_repo(tmp_path)
    assert Spt0237Layer1Service(tmp_path).audit().conformant


def test_service_writes_json(tmp_path):
    make_repo(tmp_path)
    destination = tmp_path / "out" / "audit.json"
    report = Spt0237Layer1Service(tmp_path).audit_to_json(destination)
    assert destination.exists()
    assert json.loads(destination.read_text(encoding="utf-8"))["conformant"] == report.conformant


def test_policy_can_load_json(tmp_path):
    p = tmp_path / "policy.json"
    p.write_text(json.dumps({"scope": ["SPT-023.1"], "dimensions": ["integrity"]}), encoding="utf-8")
    policy = AuditPolicy.from_json(p)
    assert policy.scope == ("SPT-023.1",)
    assert policy.dimensions == ("integrity",)


def test_policy_preserves_fail_on_error(tmp_path):
    p = tmp_path / "policy.json"
    p.write_text(json.dumps({"fail_on_error": False}), encoding="utf-8")
    assert AuditPolicy.from_json(p).fail_on_error is False


def test_auditor_is_read_only_for_fixture(tmp_path):
    make_repo(tmp_path)
    scanner = TransversalScanner(tmp_path)
    before = {str(p): scanner.sha256(p) for p in scanner.files()}
    IntelligentAuditor(tmp_path).run()
    after = {str(p): scanner.sha256(p) for p in scanner.files()}
    assert before == after


def test_scope_gap_code_is_institutional(tmp_path):
    make_component(tmp_path, 1)
    report = IntelligentAuditor(tmp_path).run()
    gaps = [f for f in report.findings if f.code == "SCOPE_GAP"]
    assert gaps and all(f.dimension == "institutional_conformity" for f in gaps)


def test_report_blocking_count_matches(tmp_path):
    make_component(tmp_path, 1)
    report = IntelligentAuditor(tmp_path).run()
    assert report.to_dict()["blocking_count"] == len(report.blocking_findings)


def test_complete_report_has_file_metric(tmp_path):
    make_repo(tmp_path)
    assert IntelligentAuditor(tmp_path).run().metrics["files_scanned"] >= 24


def test_all_scope_components_are_audited(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.scope == AuditPolicy.default().scope


def test_warning_does_not_fail_conformity():
    report = AuditReport(
        ("SPT-023.1",),
        [AuditFinding("nomenclature", "WARN", "WARNING", "warning")],
    )
    assert report.conformant
