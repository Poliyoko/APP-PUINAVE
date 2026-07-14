"""Pruebas de SPB-002.3 Entrega C."""

import json

from sgoda.cli.main import main


def initialize(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Prueba"]) == 0


def test_generate_api(tmp_path) -> None:
    initialize(tmp_path)
    assert (
        main(["generate", "api", str(tmp_path), "--name", "léxico"])
        == 0
    )
    assert (
        tmp_path / "backend" / "src" / "app" / "api" / "lexico" / "router.py"
    ).is_file()


def test_generate_workflow(tmp_path) -> None:
    initialize(tmp_path)
    assert (
        main(
            [
                "generate",
                "workflow",
                str(tmp_path),
                "--name",
                "importación-léxica",
            ]
        )
        == 0
    )
    assert (
        tmp_path / "automation" / "n8n" / "importacion_lexica.json"
    ).is_file()


def test_generate_docs(tmp_path) -> None:
    initialize(tmp_path)
    assert (
        main(["generate", "docs", str(tmp_path), "--name", "api-léxico"])
        == 0
    )
    assert (
        tmp_path / "docs" / "08_Desarrollo" / "api_lexico.md"
    ).is_file()


def test_named_components_require_name(tmp_path) -> None:
    initialize(tmp_path)
    assert main(["generate", "api", str(tmp_path)]) == 2
    assert main(["generate", "workflow", str(tmp_path)]) == 2
    assert main(["generate", "docs", str(tmp_path)]) == 2


def test_manifest_registers_delivery_c_components(tmp_path) -> None:
    initialize(tmp_path)
    main(["generate", "api", str(tmp_path), "--name", "lexico"])
    main(
        [
            "generate",
            "workflow",
            str(tmp_path),
            "--name",
            "importacion-lexica",
        ]
    )
    main(["generate", "docs", str(tmp_path), "--name", "api-lexico"])

    manifest = json.loads(
        (tmp_path / "sgoda.project.json").read_text(encoding="utf-8")
    )

    assert "api:lexico" in manifest["components"]
    assert "workflow:importacion_lexica" in manifest["components"]
    assert "docs:api_lexico" in manifest["components"]
