"""Pruebas del motor de auditoría base."""

import json

from sgoda.audit import AuditEngine, Severity
from sgoda.cli.main import main


def initialize_project(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Auditoría"]) == 0


def test_audit_valid_project_passes(tmp_path) -> None:
    initialize_project(tmp_path)

    report = AuditEngine().audit(tmp_path)

    assert report.passed is True
    assert report.errors == 0


def test_audit_detects_missing_required_file(tmp_path) -> None:
    initialize_project(tmp_path)
    (tmp_path / "README.md").unlink()

    report = AuditEngine().audit(tmp_path)

    assert report.passed is False
    assert any(
        item.rule_id == "SGODA-STRUCTURE-002"
        and item.severity is Severity.ERROR
        for item in report.findings
    )


def test_audit_detects_registered_component_without_files(tmp_path) -> None:
    initialize_project(tmp_path)
    manifest_path = tmp_path / "sgoda.project.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["components"]["api:lexico"] = {
        "type": "api",
        "name": "lexico",
        "status": "generated",
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-COMPONENT-006"
        for item in report.findings
    )


def test_audit_json_output(tmp_path, capsys) -> None:
    initialize_project(tmp_path)
    capsys.readouterr()

    assert main(["audit", str(tmp_path), "--format", "json"]) == 0
    payload = json.loads(capsys.readouterr().out)

    assert payload["status"] == "OK"
    assert payload["summary"]["errors"] == 0


def test_audit_command_returns_nonzero_on_error(tmp_path) -> None:
    initialize_project(tmp_path)
    (tmp_path / "README.md").unlink()

    assert main(["audit", str(tmp_path)]) == 1
