"""Pruebas del modo estricto y resumen de calidad."""

import json

from sgoda.audit import AuditEngine
from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Estricto"]) == 0


def test_strict_mode_returns_two_on_warning(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "sgoda.project.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["governance"].pop("data_steward")
    path.write_text(json.dumps(manifest), encoding="utf-8")

    assert main(["audit", str(tmp_path), "--strict"]) == 2


def test_normal_mode_allows_warning(tmp_path) -> None:
    initialize(tmp_path)
    path = tmp_path / "sgoda.project.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["governance"].pop("data_steward")
    path.write_text(json.dumps(manifest), encoding="utf-8")

    assert main(["audit", str(tmp_path)]) == 0


def test_quality_command(tmp_path, capsys) -> None:
    initialize(tmp_path)
    capsys.readouterr()

    assert main(["quality", str(tmp_path)]) == 0
    output = capsys.readouterr().out

    assert "Calidad SGODA" in output
    assert "Puntuación:" in output


def test_score_penalizes_errors(tmp_path) -> None:
    initialize(tmp_path)
    clean = AuditEngine().audit(tmp_path)
    (tmp_path / "README.md").unlink()
    broken = AuditEngine().audit(tmp_path)

    assert broken.score < clean.score
