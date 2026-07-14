"""Pruebas de calidad de datos y documentación."""

import json

from sgoda.audit import AuditEngine, Severity
from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Calidad"]) == 0


def test_empty_lexicon_is_information(tmp_path) -> None:
    initialize(tmp_path)

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-QUALITY-003"
        and item.severity is Severity.INFO
        for item in report.findings
    )


def test_invalid_records_shape_is_error(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "data/json/palabras.json"
    path.write_text(json.dumps({"records": {}}), encoding="utf-8")

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-QUALITY-002"
        and item.severity is Severity.ERROR
        for item in report.findings
    )


def test_missing_project_version_is_warning(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "sgoda.project.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["project"].pop("version")
    path.write_text(json.dumps(manifest), encoding="utf-8")

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-META-001"
        and item.severity is Severity.WARNING
        for item in report.findings
    )


def test_short_governance_document_is_warning(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "docs/00_Gobierno/README.md"
    path.write_text("# Gobierno\n", encoding="utf-8")

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-DOC-002"
        for item in report.findings
    )
