"""Pruebas de dependencias entre componentes."""

import json

from sgoda.audit import AuditEngine, Severity
from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Dependencias"]) == 0


def test_api_without_registered_backend_warns(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "sgoda.project.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["components"]["api:lexico"] = {
        "type": "api",
        "name": "lexico",
        "status": "generated",
    }
    path.write_text(json.dumps(manifest), encoding="utf-8")
    api_path = tmp_path / "backend/src/app/api/lexico"
    api_path.mkdir(parents=True)

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-DEPENDENCY-001"
        and item.severity is Severity.WARNING
        for item in report.findings
    )


def test_consistent_dependencies_pass(tmp_path) -> None:
    initialize(tmp_path)
    assert main(["generate", "backend", str(tmp_path)]) == 0
    assert (
        main(
            [
                "generate",
                "api",
                str(tmp_path),
                "--name",
                "lexico",
            ]
        )
        == 0
    )

    report = AuditEngine().audit(tmp_path)

    assert any(
        item.rule_id == "SGODA-DEPENDENCY-OK-001"
        for item in report.findings
    )
