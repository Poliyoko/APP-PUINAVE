"""Pruebas de informes persistentes."""

import json

from sgoda.audit import AuditEngine, render_report, save_report
from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Reportes"]) == 0


def test_markdown_report(tmp_path) -> None:
    initialize(tmp_path)

    report = AuditEngine().audit(tmp_path)
    markdown = render_report(report, "markdown")

    assert "# Informe de Auditoría SGODA" in markdown
    assert "Puntuación" in markdown


def test_save_json_report(tmp_path) -> None:
    project = tmp_path / "project"
    initialize(project)
    output = tmp_path / "reports" / "audit.json"

    report = AuditEngine().audit(project)
    saved = save_report(report, output, output_format="json")

    payload = json.loads(saved.read_text(encoding="utf-8"))
    assert payload["score"] >= 0
    assert payload["status"] == "OK"


def test_cli_saves_markdown_report(tmp_path) -> None:
    project = tmp_path / "project"
    initialize(project)
    output = tmp_path / "reports" / "audit.md"

    exit_code = main(
        [
            "audit",
            str(project),
            "--format",
            "markdown",
            "--output",
            str(output),
        ]
    )

    assert exit_code == 0
    assert output.is_file()
