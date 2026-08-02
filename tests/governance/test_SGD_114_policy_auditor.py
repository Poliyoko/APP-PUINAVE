from pathlib import Path

from sgoda.governance.policy_auditor import audit_policy_gate


def test_policy_auditor_detects_failed_boolean(tmp_path: Path) -> None:
    result = audit_policy_gate(
        tmp_path,
        {},
        {"passed": False},
        "SGD-116B",
    )

    assert result.passed is False
    assert any(
        item.code == "BOOLEAN_RULE_FAILED"
        for item in result.findings
    )


def test_policy_auditor_detects_failure_list(tmp_path: Path) -> None:
    result = audit_policy_gate(
        tmp_path,
        {},
        {"missing_evidence": ["docs/x.md"]},
        "SGD-116B",
    )

    assert result.passed is False
    assert any(
        item.code == "NON_EMPTY_FAILURE_LIST"
        for item in result.findings
    )


def test_policy_auditor_detects_missing_path(tmp_path: Path) -> None:
    result = audit_policy_gate(
        tmp_path,
        {"required_document": "docs/x.md"},
        {},
        "SGD-116B",
    )

    assert any(
        item.code == "MISSING_REFERENCED_PATH"
        for item in result.findings
    )


def test_policy_auditor_approves_complete_minimum(tmp_path: Path) -> None:
    descriptor = (
        tmp_path
        / "config"
        / "roadmap"
        / "SGD-116B-component.json"
    )
    descriptor.parent.mkdir(parents=True)
    descriptor.write_text("{}", encoding="utf-8")

    release = tmp_path / "releases" / "SGD-116B-v3.0.0"
    release.mkdir(parents=True)

    result = audit_policy_gate(
        tmp_path,
        {},
        {"passed": True},
        "SGD-116B",
    )

    assert result.passed is True
    assert result.blocking_count == 0