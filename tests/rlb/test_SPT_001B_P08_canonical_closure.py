"""Pruebas SPT-001B-P08 de consolidación y cierre."""

import hashlib
import json
from pathlib import Path

from sgoda.rlb.canonical_consolidator import (
    consolidar_repositorio,
)


def _write(path: Path, data: object) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False),
        encoding="utf-8",
    )
    return path


def _inputs(tmp_path: Path) -> dict[str, Path]:
    canonical = {
        "metadata": {
            "version_esquema": "1.0.0-p07-normalized",
        },
        "registros": [
            {
                "identificador": "LEX-0001",
                "palabra_puinave": "AMDA",
                "traduccion_espanol": "ejemplo",
                "origen": {
                    "archivo": "RLB.xlsx",
                    "hoja": "Diccionario",
                    "fila": 2,
                },
            },
            {
                "identificador": None,
                "palabra_puinave": "BETA",
                "traduccion_espanol": "segundo",
                "origen": {
                    "archivo": "RLB.xlsx",
                    "hoja": "Diccionario",
                    "fila": 3,
                },
            },
        ],
    }

    profile = {
        "total_registros": 2,
        "total_registros_validos": 2,
        "total_registros_con_errores": 0,
    }

    errors = {
        "metadata": {"total": 0},
        "errores": [],
    }

    schema = {
        "version": "1.1.0",
        "fields": [{"name": "palabra_puinave"}],
    }

    return {
        "canonical": _write(
            tmp_path / "canonical.json",
            canonical,
        ),
        "profile": _write(
            tmp_path / "profile.json",
            profile,
        ),
        "errors": _write(
            tmp_path / "errors.json",
            errors,
        ),
        "schema": _write(
            tmp_path / "schema.json",
            schema,
        ),
    }


def test_SPT_001B_P08_consolida_linea_base(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    result = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "output",
    )

    assert result.total_records == 2
    assert result.duplicate_canonical_ids == 0
    assert result.repository_path.is_file()
    assert result.statistics_path.is_file()
    assert result.validation_path.is_file()
    assert result.manifest_path.is_file()


def test_SPT_001B_P08_genera_id_deterministico(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    first = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "first",
    )
    second = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "second",
    )

    data_first = json.loads(
        first.repository_path.read_text(encoding="utf-8")
    )
    data_second = json.loads(
        second.repository_path.read_text(encoding="utf-8")
    )

    id_first = data_first["registros"][1]["canonical_id"]
    id_second = data_second["registros"][1]["canonical_id"]

    assert id_first == id_second
    assert id_first.startswith("RLB-")


def test_SPT_001B_P08_rechaza_errores_residuales(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    _write(
        paths["errors"],
        {
            "metadata": {"total": 1},
            "errores": [{"fila": 2}],
        },
    )

    try:
        consolidar_repositorio(
            canonical_input=paths["canonical"],
            profile_input=paths["profile"],
            errors_input=paths["errors"],
            schema_input=paths["schema"],
            output_dir=tmp_path / "output",
        )
    except ValueError as error:
        assert "errores residuales" in str(error)
    else:
        raise AssertionError(
            "Debía rechazarse un repositorio con errores."
        )


def test_SPT_001B_P08_manifiesto_contiene_hashes(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    result = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "output",
    )

    manifest = json.loads(
        result.manifest_path.read_text(encoding="utf-8")
    )

    assert manifest["release"] == "SPT-001B-v1.0.0"
    assert manifest["artifacts"]

    for item in manifest["artifacts"]:
        assert len(item["sha256"]) == 64
        int(item["sha256"], 16)
        assert item["size_bytes"] > 0


def test_SPT_001B_P08_validacion_final_aprobada(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    result = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "output",
    )

    validation = json.loads(
        result.validation_path.read_text(encoding="utf-8")
    )

    assert validation["passed"] is True
    assert all(validation["checks"].values())