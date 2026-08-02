"""Pruebas funcionales SPT-002 del motor ODA."""

import json
import subprocess
import sys
from pathlib import Path

from sgoda.oda.engine import (
    ejecutar_motor_oda,
    generar_oda,
    generar_repositorio_oda,
)


def _write(path: Path, data: object) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False),
        encoding="utf-8",
    )
    return path


def _fixture(tmp_path: Path) -> tuple[Path, Path]:
    canonical = {
        "metadata": {
            "release": "SPT-001B-v1.0.0",
        },
        "registros": [
            {
                "canonical_id": "LEX-0001",
                "palabra_puinave": "AMDA",
                "traduccion_espanol": "ejemplo",
                "traduccion_ingles": "example",
                "tema_cultural": "vida cotidiana",
            },
            {
                "canonical_id": "LEX-0002",
                "palabra_puinave": "BETA",
                "traduccion_espanol": "segundo",
            },
        ],
    }

    active_schema = {
        "active_schema": "config/rlb/schema-v1.1.json",
        "version": "1.1.0",
    }

    return (
        _write(tmp_path / "canonical.json", canonical),
        _write(tmp_path / "active-schema.json", active_schema),
    )


def test_SPT_002_genera_oda_deterministico() -> None:
    record = {
        "canonical_id": "LEX-0001",
        "palabra_puinave": "AMDA",
    }

    first = generar_oda(
        record=record,
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="a" * 64,
    )
    second = generar_oda(
        record=record,
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="a" * 64,
    )

    assert first.oda_id == "ODA-LEX-0001"
    assert first.oda_id == second.oda_id
    assert first.estado == "borrador_valido"


def test_SPT_002_crea_cuatro_slots_multimedia() -> None:
    oda = generar_oda(
        record={
            "canonical_id": "LEX-0001",
            "palabra_puinave": "AMDA",
        },
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="b" * 64,
    )

    assert len(oda.recursos) == 4
    assert {
        item.tipo
        for item in oda.recursos
    } == {
        "imagen_ilustrativa",
        "audio_puinave",
        "audio_espanol",
        "audio_ingles",
    }


def test_SPT_002_preserva_campos_extensibles() -> None:
    oda = generar_oda(
        record={
            "canonical_id": "LEX-0001",
            "palabra_puinave": "AMDA",
            "nuevo_campo_cultural": "valor",
        },
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="c" * 64,
    )

    assert oda.campos_extensibles[
        "nuevo_campo_cultural"
    ] == "valor"


def test_SPT_002_bloquea_registro_incompleto() -> None:
    oda = generar_oda(
        record={
            "canonical_id": "",
            "palabra_puinave": "",
        },
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="d" * 64,
    )

    assert oda.estado == "bloqueado_por_validacion"
    assert "canonical_id_obligatorio" in oda.validaciones
    assert "palabra_puinave_obligatoria" in oda.validaciones


def test_SPT_002_publica_repositorio_y_manifiesto(
    tmp_path: Path,
) -> None:
    canonical, active_schema = _fixture(tmp_path)

    execution = ejecutar_motor_oda(
        canonical_repository=canonical,
        active_schema=active_schema,
        output_dir=tmp_path / "output",
    )

    result = execution["resultado"]
    artifacts = execution["artefactos"]

    assert result.estadisticas["total_oda"] == 2
    assert result.estadisticas["oda_validos"] == 2
    assert result.estadisticas["quality_percentage"] == 100.0

    for path in artifacts.values():
        assert path.is_file()
        assert path.stat().st_size > 0

    validation = json.loads(
        artifacts["validation"].read_text(encoding="utf-8")
    )
    manifest = json.loads(
        artifacts["manifest"].read_text(encoding="utf-8")
    )

    assert validation["passed"] is True
    assert manifest["release"] == "SPT-002-v0.1.0"

    for item in manifest["artifacts"]:
        assert len(item["sha256"]) == 64


def test_SPT_002_cli_sin_advertencias(
    tmp_path: Path,
) -> None:
    canonical, active_schema = _fixture(tmp_path)
    output = tmp_path / "cli-output"

    process = subprocess.run(
        [
            sys.executable,
            "-m",
            "sgoda.oda.cli",
            "--canonical",
            str(canonical),
            "--active-schema",
            str(active_schema),
            "--output",
            str(output),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert process.returncode == 0
    assert "RuntimeWarning" not in process.stderr
    assert "SPT-002 ejecutado correctamente." in process.stdout
    assert (output / "oda-repository-v0.1.0.json").is_file()
    assert (output / "oda-statistics.json").is_file()
    assert (output / "oda-validation.json").is_file()
    assert (output / "oda-generation-event.json").is_file()
    assert (output / "oda-baseline-manifest.json").is_file()