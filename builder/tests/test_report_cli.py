import json

from sgoda.cli.main import main
from sgoda.operations import HistoryStore


def test_report_cli_markdown(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Ejecutivo"]) == 0
    capsys.readouterr()

    assert main(["report", str(tmp_path)]) == 0
    output = capsys.readouterr().out

    assert "# Reporte Ejecutivo SGODA" in output
    assert "executive_report_generated" in [
        event.event_type for event in HistoryStore(tmp_path).read_all()
    ]


def test_report_cli_json_without_history(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Sin historial"]) == 0
    capsys.readouterr()

    assert main([
        "report", str(tmp_path), "--format", "json", "--no-history"
    ]) == 0
    payload = json.loads(capsys.readouterr().out)

    assert payload["metadata"]["history_included"] is False
    assert payload["history"] == []


def test_report_cli_saves_markdown(tmp_path, capsys) -> None:
    project = tmp_path / "project"
    reports = tmp_path / "reports"
    assert main(["init", str(project), "--project-name", "Guardado"]) == 0
    capsys.readouterr()

    assert main([
        "report", str(project), "--output", str(reports)
    ]) == 0
    capsys.readouterr()

    output_file = reports / "executive-report.md"
    assert output_file.is_file()


def test_report_rejects_invalid_history_limit(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Límite"]) == 0
    capsys.readouterr()

    assert main([
        "report", str(tmp_path), "--history-limit", "0"
    ]) == 1
    assert "history_limit" in capsys.readouterr().out
