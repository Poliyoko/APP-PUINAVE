"""Pruebas de SPB-002.3 Entrega B."""

import json

from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Prueba"]) == 0


def test_frontend(tmp_path) -> None:
    initialize(tmp_path)
    assert main(["generate", "frontend", str(tmp_path)]) == 0
    assert (tmp_path / "frontend" / "web" / "index.html").is_file()


def test_database(tmp_path) -> None:
    initialize(tmp_path)
    assert main(["generate", "database", str(tmp_path)]) == 0
    assert (tmp_path / "database" / "schema.sql").is_file()


def test_module(tmp_path) -> None:
    initialize(tmp_path)
    assert (
        main(
            [
                "generate",
                "module",
                str(tmp_path),
                "--name",
                "léxico",
            ]
        )
        == 0
    )
    assert (tmp_path / "modules" / "lexico" / "README.md").is_file()


def test_module_requires_name(tmp_path) -> None:
    initialize(tmp_path)
    assert main(["generate", "module", str(tmp_path)]) == 2


def test_manifest_registry(tmp_path) -> None:
    initialize(tmp_path)
    main(["generate", "frontend", str(tmp_path)])
    main(["generate", "database", str(tmp_path)])
    main(["generate", "module", str(tmp_path), "--name", "lexico"])

    manifest = json.loads(
        (tmp_path / "sgoda.project.json").read_text(encoding="utf-8")
    )
    assert "frontend" in manifest["components"]
    assert "database" in manifest["components"]
    assert "module:lexico" in manifest["components"]
