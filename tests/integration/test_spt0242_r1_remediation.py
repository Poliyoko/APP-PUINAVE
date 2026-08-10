import json
from pathlib import Path

from sgoda.integration.spt0242r1.analysis import SafeCandidateAnalyzer, summarize
from sgoda.integration.spt0242r1.gate import RemediationSecurityGate
from sgoda.integration.spt0242r1.remediation import (
    GitignoreRemediator,
    RemediationPolicy,
)


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def candidate(path, line=1, detector="ASSIGNED_SECRET", fingerprint="FP"):
    return {
        "path": path,
        "line": line,
        "detector": detector,
        "fingerprint": fingerprint,
    }


def analyzer(root, tracked=(), history=()):
    return SafeCandidateAnalyzer(root, tracked, history)


def test_tests_context_is_false_positive(tmp_path):
    write(tmp_path / "tests" / "test_x.py", 'password = "abcdefghijkl"\n')
    item = analyzer(tmp_path).analyze_one(candidate("tests/test_x.py"))
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_docs_context_is_false_positive(tmp_path):
    write(tmp_path / "docs" / "guide.md", 'token = "abcdefghijkl"\n')
    item = analyzer(tmp_path).analyze_one(candidate("docs/guide.md"))
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_artifact_context_is_false_positive(tmp_path):
    write(
        tmp_path / "artifacts" / "development" / "x.json",
        '"secret": "abcdefghijkl"\n',
    )
    item = analyzer(tmp_path).analyze_one(
        candidate("artifacts/development/x.json")
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_detector_definition_is_false_positive(tmp_path):
    write(
        tmp_path / "src" / "security" / "secrets.py",
        'PATTERN = "-----BEGIN PRIVATE KEY-----"\n',
    )
    item = analyzer(tmp_path).analyze_one(
        candidate(
            "src/security/secrets.py",
            detector="PRIVATE_KEY_MARKER",
        )
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_environment_reference_is_false_positive(tmp_path):
    write(tmp_path / "src" / "settings.py", 'token = os.getenv("TOKEN")\n')
    item = analyzer(tmp_path).analyze_one(
        candidate("src/settings.py")
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_placeholder_is_false_positive(tmp_path):
    write(tmp_path / "src" / "settings.py", 'token = "CHANGEME"\n')
    item = analyzer(tmp_path).analyze_one(candidate("src/settings.py"))
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_private_key_in_runtime_is_confirmed(tmp_path):
    write(
        tmp_path / "src" / "runtime.py",
        "-----BEGIN PRIVATE KEY-----\n",
    )
    item = analyzer(tmp_path).analyze_one(
        candidate(
            "src/runtime.py",
            detector="PRIVATE_KEY_MARKER",
        )
    )
    assert item.disposition == "CONFIRMED_RISK"
    assert item.requires_rotation is True


def test_assigned_secret_in_config_is_confirmed(tmp_path):
    write(tmp_path / "config" / "prod.json", '"token": "abcdefghijkl"\n')
    item = analyzer(tmp_path).analyze_one(
        candidate("config/prod.json")
    )
    assert item.disposition == "CONFIRMED_RISK"


def test_unknown_source_requires_review(tmp_path):
    write(tmp_path / "src" / "worker.py", 'token = "abcdefghijkl"\n')
    item = analyzer(tmp_path).analyze_one(candidate("src/worker.py"))
    assert item.disposition == "REVIEW_REQUIRED"


def test_tracked_flag_is_metadata_only(tmp_path):
    write(tmp_path / "config" / "prod.json", '"token": "abcdefghijkl"\n')
    item = analyzer(tmp_path, tracked=["config/prod.json"]).analyze_one(
        candidate("config/prod.json")
    )
    assert item.tracked is True


def test_history_flag_is_metadata_only(tmp_path):
    write(tmp_path / "config" / "prod.json", '"token": "abcdefghijkl"\n')
    item = analyzer(tmp_path, history=["config/prod.json"]).analyze_one(
        candidate("config/prod.json")
    )
    assert item.history_reference is True


def _published_master_fixture(tmp_path, line_no, content, detector="ASSIGNED_SECRET"):
    master = tmp_path / "Invoke-SGODA-SPT0241-Capa1-FINAL-v1.0.0-PS51.ps1"
    lines = ["# filler"] * 1060
    lines[line_no - 1] = content
    write(master, "\n".join(lines) + "\n")
    return analyzer(tmp_path, tracked=[master.name], history=[master.name]).analyze_one(
        candidate(master.name, line=line_no, detector=detector)
    )


def test_published_master_fixture_1000_is_false_positive(tmp_path):
    item = _published_master_fixture(
        tmp_path,
        1000,
        '    path = write(tmp_path / "config.py", \'api_key = "1234567890ABCDEF"\\n\')',
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_published_master_fixture_1007_is_false_positive(tmp_path):
    item = _published_master_fixture(
        tmp_path,
        1007,
        '    path = write(tmp_path / "x.txt", "-----BEGIN PRIVATE KEY-----\\n")',
        detector="PRIVATE_KEY_MARKER",
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_published_master_fixture_1013_is_false_positive(tmp_path):
    item = _published_master_fixture(
        tmp_path,
        1013,
        '    path = write(tmp_path / "x.png", \'token="1234567890"\\n\')',
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_published_master_fixture_1018_is_false_positive(tmp_path):
    item = _published_master_fixture(
        tmp_path,
        1018,
        '    path = write(tmp_path / "config.py", \'secret = "abcdefghijkl"\\n\')',
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_published_master_fixture_1058_is_false_positive(tmp_path):
    item = _published_master_fixture(
        tmp_path,
        1058,
        '    write(tmp_path / "config.py", \'password = "abcdefghijkl"\\n\')',
    )
    assert item.disposition == "CERTIFIED_FALSE_POSITIVE"


def test_summary_counts_false_positive(tmp_path):
    write(tmp_path / "tests" / "x.py", 'token = "abcdefghijkl"\n')
    items = analyzer(tmp_path).analyze_many([candidate("tests/x.py")])
    assert summarize(items)["certified_false_positives"] == 1


def test_summary_never_exposes_values(tmp_path):
    assert summarize([])["secret_values_exposed"] is False


def test_gitignore_plan_detects_missing(tmp_path):
    write(tmp_path / ".gitignore", "__pycache__/\n")
    plan = GitignoreRemediator(tmp_path).plan()
    assert ".env" in plan["missing_patterns"]


def test_gitignore_apply_adds_patterns(tmp_path):
    write(tmp_path / ".gitignore", "__pycache__/\n")
    GitignoreRemediator(tmp_path).apply()
    content = (tmp_path / ".gitignore").read_text(encoding="utf-8")
    assert ".env" in content
    assert "*.key" in content


def test_gitignore_apply_is_idempotent(tmp_path):
    write(tmp_path / ".gitignore", ".env\n.env.*\n*.pem\n*.key\n*.pfx\n*.p12\n")
    first = GitignoreRemediator(tmp_path).apply()
    second = GitignoreRemediator(tmp_path).apply()
    assert first["changed"] is False
    assert second["changed"] is False


def test_policy_only_allows_low_risk_auto_remediation():
    data = RemediationPolicy.to_dict()
    assert data["automatic"] == ["ADD_GITIGNORE_SECRET_PATTERNS"]


def test_policy_requires_manual_rotation():
    assert "ROTATE_CREDENTIAL" in RemediationPolicy.to_dict()["manual_or_followup"]


def test_gate_passes_clean_classification(tmp_path):
    write(tmp_path / "tests" / "x.py", 'token = "abcdefghijkl"\n')
    findings = analyzer(tmp_path).analyze_many([candidate("tests/x.py")])
    gate = RemediationSecurityGate.certify(
        findings,
        gitignore_passed=True,
    )
    assert gate.passed is True


def test_gate_blocks_confirmed_risk(tmp_path):
    write(tmp_path / "config" / "prod.json", '"token": "abcdefghijkl"\n')
    findings = analyzer(tmp_path).analyze_many([candidate("config/prod.json")])
    gate = RemediationSecurityGate.certify(
        findings,
        gitignore_passed=True,
    )
    assert gate.passed is False


def test_gate_blocks_review_required(tmp_path):
    write(tmp_path / "src" / "worker.py", 'token = "abcdefghijkl"\n')
    findings = analyzer(tmp_path).analyze_many([candidate("src/worker.py")])
    gate = RemediationSecurityGate.certify(
        findings,
        gitignore_passed=True,
    )
    assert "CANDIDATES_REQUIRE_MANUAL_REVIEW" in gate.blocking_reasons


def test_gate_blocks_gitignore_failure():
    gate = RemediationSecurityGate.certify([], gitignore_passed=False)
    assert gate.passed is False


def test_gate_reports_tracked_risk(tmp_path):
    write(tmp_path / "config" / "prod.json", '"token": "abcdefghijkl"\n')
    findings = analyzer(
        tmp_path,
        tracked=["config/prod.json"],
    ).analyze_many([candidate("config/prod.json")])
    gate = RemediationSecurityGate.certify(
        findings,
        gitignore_passed=True,
    )
    assert gate.tracked_confirmed_risks == 1


def test_gate_reports_history_risk(tmp_path):
    write(tmp_path / "config" / "prod.json", '"token": "abcdefghijkl"\n')
    findings = analyzer(
        tmp_path,
        history=["config/prod.json"],
    ).analyze_many([candidate("config/prod.json")])
    gate = RemediationSecurityGate.certify(
        findings,
        gitignore_passed=True,
    )
    assert gate.history_confirmed_risks == 1
