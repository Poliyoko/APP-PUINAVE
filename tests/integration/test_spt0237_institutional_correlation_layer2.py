from pathlib import Path

from sgoda.integration.spt0237.correlation import FindingCorrelator
from sgoda.integration.spt0237.crosscheck import CrossComponentConsistencyEngine
from sgoda.integration.spt0237.evidence import EvidenceConsolidator
from sgoda.integration.spt0237.layer2 import Spt0237Layer2Service
from sgoda.integration.spt0237.models import AuditFinding
from sgoda.integration.spt0237.risk import InstitutionalRiskEvaluator
from sgoda.integration.spt0237.verdict import InstitutionalVerdictEngine


def finding(subject="SPT-023.1", dimension="quality", code="X", severity="WARNING"):
    return AuditFinding(
        dimension=dimension,
        code=code,
        severity=severity,
        message="message",
        subject=subject,
        evidence={"x": 1},
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


def test_correlator_groups_same_subject():
    result = FindingCorrelator.correlate([finding(), finding(code="Y")])
    assert len(result) == 1
    assert result[0].finding_count == 2


def test_correlator_separates_subjects():
    result = FindingCorrelator.correlate([
        finding(subject="SPT-023.1"),
        finding(subject="SPT-023.2"),
    ])
    assert len(result) == 2


def test_correlator_collects_dimensions():
    result = FindingCorrelator.correlate([
        finding(dimension="quality"),
        finding(dimension="traceability"),
    ])
    assert set(result[0].dimensions) == {"quality", "traceability"}


def test_risk_none_without_findings():
    risk = InstitutionalRiskEvaluator.evaluate([], [])
    assert risk.level == "NONE"
    assert risk.score == 0


def test_risk_low_for_warning():
    findings = [finding(severity="WARNING")]
    correlations = FindingCorrelator.correlate(findings)
    assert InstitutionalRiskEvaluator.evaluate(findings, correlations).level == "LOW"


def test_risk_high_for_blocking_error():
    findings = [finding(severity="ERROR")]
    correlations = FindingCorrelator.correlate(findings)
    risk = InstitutionalRiskEvaluator.evaluate(findings, correlations)
    assert risk.level == "HIGH"
    assert risk.blocking_findings == 1


def test_multi_dimension_correlation_adds_penalty():
    findings = [
        finding(dimension="quality"),
        finding(dimension="traceability"),
    ]
    correlations = FindingCorrelator.correlate(findings)
    risk = InstitutionalRiskEvaluator.evaluate(findings, correlations)
    assert risk.score >= 3


def test_evidence_bundle_is_deterministic():
    findings = [finding(code="A"), finding(code="B")]
    one = EvidenceConsolidator.consolidate(findings)
    two = EvidenceConsolidator.consolidate(reversed(findings))
    assert one.sha256 == two.sha256


def test_evidence_sha256_has_64_chars():
    assert len(EvidenceConsolidator.consolidate([finding()]).sha256) == 64


def test_evidence_bundle_counts_findings():
    assert EvidenceConsolidator.consolidate([finding(), finding(code="Y")]).finding_count == 2


def test_crosscheck_detects_scope_gap():
    result = CrossComponentConsistencyEngine.detect([
        finding(subject="SPT-023.4", code="SCOPE_GAP", severity="ERROR")
    ])
    assert any(item.code == "PIPELINE_SCOPE_INCOMPLETE" for item in result)


def test_crosscheck_detects_multi_component_blocking():
    result = CrossComponentConsistencyEngine.detect([
        finding(subject="SPT-023.1", severity="ERROR"),
        finding(subject="SPT-023.2", severity="CRITICAL"),
    ])
    assert any(item.code == "MULTI_COMPONENT_BLOCKING_RISK" for item in result)


def test_crosscheck_detects_traceability_weakness():
    result = CrossComponentConsistencyEngine.detect([
        finding(subject="SPT-023.1", code="EVIDENCE_NOT_DISCOVERED"),
        finding(subject="SPT-023.2", code="EVIDENCE_NOT_DISCOVERED"),
    ])
    assert any(item.code == "TRACEABILITY_CHAIN_WEAKNESS" for item in result)


def test_crosscheck_empty_for_clean_findings():
    assert CrossComponentConsistencyEngine.detect([]) == []


def test_verdict_approves_clean_report():
    evidence = EvidenceConsolidator.consolidate([])
    risk = InstitutionalRiskEvaluator.evaluate([], [])
    verdict = InstitutionalVerdictEngine.issue(
        report_conformant=True,
        risk=risk,
        evidence=evidence,
        cross_inconsistency_count=0,
        blocking_cross_inconsistency_count=0,
    )
    assert verdict.publishable is True
    assert verdict.status == "INSTITUTIONAL_AUDIT_APPROVED"


def test_verdict_holds_nonconformant_report():
    evidence = EvidenceConsolidator.consolidate([finding(severity="ERROR")])
    risk = InstitutionalRiskEvaluator.evaluate(
        [finding(severity="ERROR")],
        FindingCorrelator.correlate([finding(severity="ERROR")]),
    )
    verdict = InstitutionalVerdictEngine.issue(
        report_conformant=False,
        risk=risk,
        evidence=evidence,
        cross_inconsistency_count=0,
        blocking_cross_inconsistency_count=0,
    )
    assert verdict.publishable is False


def test_verdict_holds_cross_component_blocker():
    evidence = EvidenceConsolidator.consolidate([])
    risk = InstitutionalRiskEvaluator.evaluate([], [])
    verdict = InstitutionalVerdictEngine.issue(
        report_conformant=True,
        risk=risk,
        evidence=evidence,
        cross_inconsistency_count=1,
        blocking_cross_inconsistency_count=1,
    )
    assert "BLOCKING_CROSS_COMPONENT_INCONSISTENCIES" in verdict.blocking_reasons


def test_layer2_reuses_layer1(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["layer1_reused"] is True


def test_layer2_does_not_mutate_closed_components(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["closed_components_mutated"] is False


def test_layer2_disables_paid_api(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["paid_api_used"] is False


def test_layer2_points_to_layer3(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["next_component"] == "SPT-023.7-CAPA-3"


def test_layer2_clean_fixture_is_approved(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["verdict"]["status"] == "INSTITUTIONAL_AUDIT_APPROVED"


def test_layer2_clean_fixture_risk_is_not_high(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["risk"]["level"] in {"NONE", "LOW", "MEDIUM"}


def test_layer2_returns_evidence_bundle(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert len(result["evidence_bundle"]["sha256"]) == 64


def test_layer2_scope_covers_six_components(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert len(result["scope"]) == 6


def test_layer2_output_contains_correlations(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert "correlations" in result
