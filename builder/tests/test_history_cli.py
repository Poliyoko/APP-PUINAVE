import json

from sgoda.cli.main import main


def test_history_records_status_and_lists(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Historia"]) == 0
    capsys.readouterr()

    assert main([
        "history",
        str(tmp_path),
        "--record-status",
    ]) == 0
    output = capsys.readouterr().out
    assert "status_collected" in output
    assert "Eventos: 2" in output


def test_history_json_and_filter(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Historia"]) == 0
    capsys.readouterr()
    assert main([
        "history",
        str(tmp_path),
        "--record-status",
        "--format",
        "json",
    ]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["count"] == 2

    assert main([
        "history",
        str(tmp_path),
        "--type",
        "status_collected",
        "--format",
        "json",
    ]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["events"][0]["health"] == "HEALTHY"
