"""Pruebas FAIR y CARE."""

import json

from sgoda.audit import AuditEngine, Severity
from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "FAIR CARE"]) == 0


def test_missing_catalog_is_error(tmp_path) -> None:
    initialize(tmp_path)
    (tmp_path / "data/metadata/catalog.json").unlink()

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-FAIR-002"
        and item.severity is Severity.ERROR
        for item in report.findings
    )


def test_incomplete_catalog_is_warning(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "data/metadata/catalog.json"
    path.write_text(json.dumps({"title": "Catálogo"}), encoding="utf-8")

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-FAIR-004"
        and item.severity is Severity.WARNING
        for item in report.findings
    )


def test_incomplete_care_is_warning(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "sgoda.project.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["governance"]["care"]["ethics"] = False
    path.write_text(json.dumps(manifest), encoding="utf-8")

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-CARE-002"
        for item in report.findings
    )
