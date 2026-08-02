"""Pruebas SPT-003B de adaptadores multimedia."""

import json
from pathlib import Path

from sgoda.automation.adapters.contracts import SolicitudProveedor
from sgoda.automation.adapters.n8n import PublicadorEventosArchivo
from sgoda.automation.adapters.processor import (
    ProcesadorTrabajosMultimedia,
)
from sgoda.automation.adapters.providers import (
    ProveedorExternoDeshabilitado,
    ProveedorSimulado,
    construir_proveedor,
)
from sgoda.automation.adapters.storage import (
    AlmacenamientoLocalRMR,
)
from sgoda.automation.job_queue import ColaTrabajosMultimedia
from sgoda.automation.models import TrabajoMultimedia


def _job(
    index: int,
    *,
    job_type: str = "generate_image",
    payload: dict | None = None,
) -> TrabajoMultimedia:
    return TrabajoMultimedia(
        job_id=f"JOB-{index:04d}",
        resource_id=f"RMR-{index:04d}",
        oda_id=f"ODA-{index:04d}",
        canonical_id=f"LEX-{index:04d}",
        job_type=job_type,
        language="es" if job_type == "generate_tts" else None,
        payload=payload or {},
    )


def test_SPT_003B_proveedor_mock_imagen() -> None:
    provider = ProveedorSimulado()
    request = SolicitudProveedor(
        job_id="JOB-1",
        job_type="generate_image",
        resource_id="RMR-1",
        oda_id="ODA-1",
        language=None,
        payload={"prompt": "árbol"},
    )

    result = provider.execute(request)

    assert result.success is True
    assert result.media_type == "image/png"
    assert result.media_bytes
    assert result.external_id.startswith("MOCK-")


def test_SPT_003B_proveedor_mock_tts() -> None:
    provider = ProveedorSimulado()
    request = SolicitudProveedor(
        job_id="JOB-2",
        job_type="generate_tts",
        resource_id="RMR-2",
        oda_id="ODA-2",
        language="es",
        payload={"text": "ejemplo"},
    )

    result = provider.execute(request)

    assert result.success is True
    assert result.media_type == "audio/wav"


def test_SPT_003B_proveedor_no_soportado() -> None:
    provider = ProveedorSimulado()
    request = SolicitudProveedor(
        job_id="JOB-3",
        job_type="unknown",
        resource_id="RMR-3",
        oda_id="ODA-3",
        language=None,
    )

    result = provider.execute(request)

    assert result.success is False
    assert "no soportado" in result.error


def test_SPT_003B_credenciales_no_expuestas(
    monkeypatch,
) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    provider = ProveedorExternoDeshabilitado(
        name="openai-image",
        required_environment_variable="OPENAI_API_KEY",
    )

    result = provider.execute(
        SolicitudProveedor(
            job_id="JOB-4",
            job_type="generate_image",
            resource_id="RMR-4",
            oda_id="ODA-4",
            language=None,
        )
    )

    assert result.success is False
    assert "OPENAI_API_KEY" in result.error


def test_SPT_003B_almacenamiento_sha256(
    tmp_path: Path,
) -> None:
    storage = AlmacenamientoLocalRMR(root=tmp_path / "media")
    result = storage.store(
        resource_id="RMR-0001",
        media_bytes=b"contenido",
        media_type="image/png",
        metadata={"source": "test"},
    )

    assert Path(result.uri).is_file()
    assert len(result.sha256) == 64
    assert result.size_bytes == len(b"contenido")


def test_SPT_003B_evento_n8n_jsonl(
    tmp_path: Path,
) -> None:
    path = tmp_path / "events.jsonl"
    publisher = PublicadorEventosArchivo(path)

    publisher.publish(
        event_type="MultimediaJobCompleted",
        payload={"job_id": "JOB-1"},
    )

    line = path.read_text(encoding="utf-8").strip()
    payload = json.loads(line)

    assert payload["n8n_compatible"] is True
    assert payload["event_type"] == "MultimediaJobCompleted"


def test_SPT_003B_procesa_lote_completo(
    tmp_path: Path,
) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([
        _job(1),
        _job(2, job_type="generate_tts"),
        _job(3, job_type="record_native_audio"),
    ])

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=construir_proveedor("mock"),
        storage=AlmacenamientoLocalRMR(
            root=tmp_path / "media"
        ),
        events=PublicadorEventosArchivo(
            tmp_path / "events.jsonl"
        ),
    )

    summary = processor.process_batch(limit=10)

    assert summary["leased"] == 3
    assert summary["completed"] == 3
    assert queue.count("completed") == 3


def test_SPT_003B_reintenta_error_proveedor(
    tmp_path: Path,
) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([
        _job(
            1,
            payload={"simulate_error": True},
        )
    ])

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=ProveedorSimulado(),
        storage=AlmacenamientoLocalRMR(
            root=tmp_path / "media"
        ),
        events=PublicadorEventosArchivo(
            tmp_path / "events.jsonl"
        ),
    )

    summary = processor.process_batch(limit=1)

    assert summary["leased"] == 1
    assert summary["retried"] == 1
    assert queue.count("pending") == 1


def test_SPT_003B_fabrica_proveedores() -> None:
    assert construir_proveedor("mock").name == "mock-provider"
    assert construir_proveedor("openai-image").name == "openai-image"
    assert construir_proveedor("google-tts").name == "google-tts"


def test_SPT_003B_procesamiento_masivo_1000(
    tmp_path: Path,
) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many(
        _job(index)
        for index in range(1000)
    )

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=ProveedorSimulado(),
        storage=AlmacenamientoLocalRMR(
            root=tmp_path / "media"
        ),
        events=PublicadorEventosArchivo(
            tmp_path / "events.jsonl"
        ),
    )

    total_completed = 0

    while queue.count("pending") > 0:
        summary = processor.process_batch(limit=250)
        total_completed += summary["completed"]

    assert total_completed == 1000
    assert queue.count("completed") == 1000