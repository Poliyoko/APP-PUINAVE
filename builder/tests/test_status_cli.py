import json

from sgoda.cli.main import main


def test_status_text(tmp_path, capsys) -> None:
    main(["init", str(tmp_path), "--project-name", "Estado"])
    capsys.readouterr()

    assert main(["status", str(tmp_path)]) == 0
    output = capsys.readouterr().out
    assert "Estado Operativo SGODA" in output
    assert "Estado general: HEALTHY" in output
    assert "Puntuación: 100/100" in output


def test_status_json_detailed(tmp_path, capsys) -> None:
    main(["init", str(tmp_path), "--project-name", "JSON"])
    capsys.readouterr()

    assert main(["status", str(tmp_path), "--format", "json", "--detailed"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["builder_version"] == "1.11.0"
    assert payload["project"]["name"] == "JSON"
    assert payload["audit"]["score"] == 100


def test_status_rejects_non_project(tmp_path, capsys) -> None:
    assert main(["status", str(tmp_path)]) == 1
    assert "No existe el manifiesto" in capsys.readouterr().out
