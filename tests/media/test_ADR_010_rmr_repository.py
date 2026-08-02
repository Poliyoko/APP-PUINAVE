"""Pruebas ADR-010 del Repositorio Multimedia Relacional."""

import json
import sqlite3
from pathlib import Path

import pytest

from sgoda.media import (
    ConsultaRecursosRMR,
    RecursoMultimediaRMR,
    RepositorioMultimediaRMR,
    deterministic_resource_id,
    migrar_oda_a_rmr,
)


def _resource(
    index: int,
    resource_type: str = "imagen_ilustrativa",
) -> RecursoMultimediaRMR:
    oda_id = f"ODA-{index:06d}"

    return RecursoMultimediaRMR(
        resource_id=deterministic_resource_id(
            oda_id=oda_id,
            resource_type=resource_type,
            language=None,
        ),
        oda_id=oda_id,
        canonical_id=f"LEX-{index:06d}",
        resource_type=resource_type,
        status="pendiente",
        metadata={"index": index},
    )


def test_ADR_010_crea_tablas_e_indices(
    tmp_path: Path,
) -> None:
    database = tmp_path / "rmr.sqlite3"
    repository = RepositorioMultimediaRMR(database)
    repository.initialize()

    with sqlite3.connect(database) as connection:
        tables = {
            row[0]
            for row in connection.execute(
                """
                SELECT name
                FROM sqlite_master
                WHERE type = 'table'
                """
            )
        }
        indexes = {
            row[0]
            for row in connection.execute(
                """
                SELECT name
                FROM sqlite_master
                WHERE type = 'index'
                  AND tbl_name = 'media_resources'
                """
            )
        }

    assert "media_resources" in tables
    assert "rmr_metadata" in tables
    assert "idx_rmr_oda_id" in indexes
    assert "idx_rmr_oda_type_status" in indexes


def test_ADR_010_upsert_es_idempotente(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()

    resource = _resource(1)
    repository.upsert(resource)
    resource.status = "disponible"
    repository.upsert(resource)

    assert repository.count() == 1
    stored = repository.get(resource.resource_id)
    assert stored is not None
    assert stored.status == "disponible"


def test_ADR_010_admite_tipos_dinamicos(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()

    types = [
        "imagen_ilustrativa",
        "audio_puinave",
        "video_cultural",
        "modelo_3d",
        "actividad_interactiva",
        "recurso_futuro_no_previsto",
    ]

    repository.bulk_upsert(
        _resource(index, resource_type)
        for index, resource_type in enumerate(
            types,
            start=1,
        )
    )

    statistics = repository.statistics()

    assert repository.count() == len(types)
    assert statistics["unique_resource_types"] == len(types)
    assert statistics["by_type"][
        "recurso_futuro_no_previsto"
    ] == 1


def test_ADR_010_consulta_paginada_y_filtrada(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()

    resources = []

    for index in range(250):
        resource = _resource(
            index,
            "audio_puinave"
            if index % 2 == 0
            else "imagen_ilustrativa",
        )
        resource.language = (
            "pui"
            if resource.resource_type == "audio_puinave"
            else None
        )
        resources.append(resource)

    repository.bulk_upsert(resources)

    page = repository.query(
        ConsultaRecursosRMR(
            resource_type="audio_puinave",
            language="pui",
            limit=25,
            offset=25,
        )
    )

    assert len(page) == 25
    assert all(
        item.resource_type == "audio_puinave"
        for item in page
    )


def test_ADR_010_migra_slots_oda(
    tmp_path: Path,
) -> None:
    oda_repository = {
        "objetos_digitales_aprendizaje": [
            {
                "oda_id": "ODA-LEX-0001",
                "canonical_id": "LEX-0001",
                "recursos": [
                    {
                        "tipo": "imagen_ilustrativa",
                        "estado": "pendiente_generacion_ia",
                    },
                    {
                        "tipo": "audio_puinave",
                        "estado": "pendiente_grabacion_nativa",
                    },
                    {
                        "tipo": "audio_espanol",
                        "estado": "pendiente_tts",
                    },
                    {
                        "tipo": "audio_ingles",
                        "estado": "pendiente_tts",
                    },
                ],
            }
        ]
    }

    source = tmp_path / "oda.json"
    source.write_text(
        json.dumps(oda_repository),
        encoding="utf-8",
    )

    database = tmp_path / "rmr.sqlite3"

    result = migrar_oda_a_rmr(
        oda_repository_path=source,
        database_path=database,
    )

    repository = RepositorioMultimediaRMR(database)

    assert result.total_oda == 1
    assert result.total_resources == 4
    assert result.errors == []
    assert repository.count() == 4


def test_ADR_010_exporta_jsonl_en_flujo(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()
    repository.bulk_upsert(
        _resource(index)
        for index in range(1000)
    )

    output = repository.export_jsonl(
        tmp_path / "resources.jsonl",
        page_size=137,
    )

    lines = output.read_text(
        encoding="utf-8"
    ).splitlines()

    assert len(lines) == 1000
    assert json.loads(lines[0])["resource_id"]


@pytest.mark.capacity_120k
def test_ADR_010_capacidad_real_120000_recursos(
    tmp_path: Path,
) -> None:
    """Prueba funcional real del objetivo mínimo de capacidad."""

    total = 120_000
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr-capacity.sqlite3"
    )
    repository.initialize()

    processed = repository.bulk_upsert(
        (
            RecursoMultimediaRMR(
                resource_id=f"RMR-CAP-{index:012d}",
                oda_id=f"ODA-{index // 10:08d}",
                canonical_id=f"LEX-{index // 10:08d}",
                resource_type=(
                    "imagen_ilustrativa"
                    if index % 4 == 0
                    else "audio_puinave"
                    if index % 4 == 1
                    else "audio_espanol"
                    if index % 4 == 2
                    else "audio_ingles"
                ),
                language=(
                    None
                    if index % 4 == 0
                    else "pui"
                    if index % 4 == 1
                    else "es"
                    if index % 4 == 2
                    else "en"
                ),
                status="pendiente",
            )
            for index in range(total)
        ),
        batch_size=5000,
    )

    validation = repository.validate_repository()
    statistics = repository.statistics()

    assert processed == total
    assert repository.count() == total
    assert statistics["total_resources"] == total
    assert statistics["unique_resource_types"] == 4
    assert validation["passed"] is True