"""Pruebas de gobierno DAMA-DMBOK y responsables."""

import json

from sgoda.audit import AuditEngine, Severity
from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Gobierno"]) == 0


def read_manifest(tmp_path):
    path = tmp_path / "sgoda.project.json"
    return path, json.loads(path.read_text(encoding="utf-8"))


def test_valid_governance_passes(tmp_path) -> None:
    initialize(tmp_path)

    report = AuditEngine().audit(tmp_path)

    assert not any(
        item.rule_id.startswith("SGODA-GOV-")
        and item.severity is Severity.ERROR
        for item in report.findings
    )
    assert any(
        item.rule_id == "SGODA-GOV-OK-002"
        for item in report.findings
    )


def test_missing_data_owner_is_error(tmp_path) -> None:
    initialize(tmp_path)
    path, manifest = read_manifest(tmp_path)
    manifest["governance"]["data_owner"] = ""
    path.write_text(json.dumps(manifest), encoding="utf-8")

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-GOV-002"
        and item.severity is Severity.ERROR
        for item in report.findings
    )


def test_missing_steward_is_warning(tmp_path) -> None:
    initialize(tmp_path)
    path, manifest = read_manifest(tmp_path)
    manifest["governance"].pop("data_steward")
    path.write_text(json.dumps(manifest), encoding="utf-8")

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-GOV-003"
        and item.severity is Severity.WARNING
        for item in report.findings
    )
