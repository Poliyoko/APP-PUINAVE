"""Pruebas funcionales SPT-003A."""

import json
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sgoda.automation.job_queue import (
    ColaTrabajosMultimedia,
    deterministic_job_id,
)
from sgoda.automation.models import TrabajoMultimedia
from sgoda.automation.planner import planificar


def _job(index: int) -> TrabajoMultimedia:
    resource_id = f"RMR-{index:04d}"
    return TrabajoMultimedia(
        job_id=deterministic_job_id(
            resource_id,
            "generate_image",
        ),
        resource_id=resource_id,
        oda_id=f"ODA-{index:04d}",
        canonical_id=f"LEX-{index:04d}",
        job_type="generate_image",
        language=None,
        payload={"prompt": f"Imagen {index}"},
    )


def test_SPT_003A_job_id_deterministico() -> None:
    first = deterministic_job_id("RMR-1", "generate_image")
    second = deterministic_job_id("RMR-1", "generate_image")
    assert first == second
    assert first.startswith("JOB-")


def test_SPT_003A_insercion_idempotente(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()

    inserted, existing = queue.upsert_many([_job(1), _job(2)])
    inserted_2, existing_2 = queue.upsert_many([_job(1), _job(2)])

    assert (inserted, existing) == (2, 0)
    assert (inserted_2, existing_2) == (0, 2)
    assert queue.count() == 2


def test_SPT_003A_lease_y_completion(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([_job(1)])

    jobs = queue.lease(worker_id="worker-test", limit=1)
    assert len(jobs) == 1
    assert jobs[0].status == "leased"

    queue.complete(jobs[0].job_id, {"uri": "media/image.png"})
    assert queue.count("completed") == 1


def test_SPT_003A_reintentos_y_fallo_final(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()

    job = _job(1)
    job.max_attempts = 2
    queue.upsert_many([job])

    leased = queue.lease(worker_id="worker")[0]
    queue.fail(leased.job_id, "error uno", retry_delay_seconds=0)
    assert queue.count("pending") == 1

    leased = queue.lease(worker_id="worker")[0]
    queue.fail(leased.job_id, "error dos", retry_delay_seconds=0)
    assert queue.count("failed") == 1


def test_SPT_003A_recupera_leases_vencidos(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([_job(1)])
    leased = queue.lease(worker_id="worker")[0]

    expired = (
        datetime.now(timezone.utc) - timedelta(minutes=5)
    ).isoformat()

    with queue.connect() as connection:
        connection.execute(
            """
            UPDATE multimedia_jobs
            SET lease_until_utc=?
            WHERE job_id=?
            """,
            (expired, leased.job_id),
        )

    assert queue.recover_expired_leases() == 1
    assert queue.count("pending") == 1


def _create_rmr(path: Path) -> None:
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        CREATE TABLE media_resources(
            resource_id TEXT PRIMARY KEY,
            oda_id TEXT NOT NULL,
            canonical_id TEXT NOT NULL,
            resource_type TEXT NOT NULL,
            language TEXT
        );
        """
    )
    rows = [
        ("RMR-IMG", "ODA-1", "LEX-1", "imagen_ilustrativa", None),
        ("RMR-PUI", "ODA-1", "LEX-1", "audio_puinave", "pui"),
        ("RMR-ES", "ODA-1", "LEX-1", "audio_espanol", "es"),
        ("RMR-EN", "ODA-1", "LEX-1", "audio_ingles", "en"),
    ]
    connection.executemany(
        "INSERT INTO media_resources VALUES (?, ?, ?, ?, ?)",
        rows,
    )
    connection.commit()
    connection.close()


def _create_oda(path: Path) -> None:
    payload = {
        "objetos_digitales_aprendizaje": [
            {
                "oda_id": "ODA-1",
                "canonical_id": "LEX-1",
                "palabra_puinave": "AMDA",
                "traduccion_espanol": "ejemplo",
                "traduccion_ingles": "example",
                "tema_cultural": "vida cotidiana",
            }
        ]
    }
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_SPT_003A_planifica_cuatro_recursos(tmp_path: Path) -> None:
    rmr = tmp_path / "rmr.sqlite3"
    oda = tmp_path / "oda.json"
    jobs = tmp_path / "jobs.sqlite3"
    _create_rmr(rmr)
    _create_oda(oda)

    summary = planificar(
        rmr_database=rmr,
        oda_repository=oda,
        jobs_database=jobs,
    )

    assert summary.resources_seen == 4
    assert summary.jobs_planned == 4
    assert summary.jobs_inserted == 4
    assert summary.unsupported_resources == 0


def test_SPT_003A_prompt_imagen_respetuoso(tmp_path: Path) -> None:
    rmr = tmp_path / "rmr.sqlite3"
    oda = tmp_path / "oda.json"
    jobs = tmp_path / "jobs.sqlite3"
    _create_rmr(rmr)
    _create_oda(oda)

    planificar(
        rmr_database=rmr,
        oda_repository=oda,
        jobs_database=jobs,
    )

    connection = sqlite3.connect(jobs)
    payload_json = connection.execute(
        """
        SELECT payload_json
        FROM multimedia_jobs
        WHERE job_type='generate_image'
        """
    ).fetchone()[0]
    connection.close()

    payload = json.loads(payload_json)
    assert "AMDA" in payload["prompt"]
    assert "culturalmente respetuosa" in payload["prompt"]
    assert payload["human_review_required"] is True


def test_SPT_003A_escala_120000_trabajos(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()

    total = 120_000
    inserted, existing = queue.upsert_many(
        (
            TrabajoMultimedia(
                job_id=f"JOB-CAP-{index:012d}",
                resource_id=f"RMR-CAP-{index:012d}",
                oda_id=f"ODA-{index // 4:08d}",
                canonical_id=f"LEX-{index // 4:08d}",
                job_type=(
                    "generate_image"
                    if index % 4 == 0
                    else "record_native_audio"
                    if index % 4 == 1
                    else "generate_tts"
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
            )
            for index in range(total)
        ),
        batch_size=5000,
    )

    assert inserted == total
    assert existing == 0
    assert queue.count() == total