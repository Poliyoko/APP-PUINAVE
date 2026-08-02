"""Pruebas SPT-006."""

import json
import sqlite3
from pathlib import Path

from sgoda.enrichment.models import GeneratedResource
from sgoda.enrichment.pipeline import EnrichmentPipeline, run_pipeline
from sgoda.enrichment.planner import (
    create_job,
    detect_needs,
    plan_repository,
)
from sgoda.enrichment.playback import build_playback_manifest
from sgoda.enrichment.providers import MockEnrichmentProvider


def _canonical(tmp_path: Path) -> Path:
    path = tmp_path / "canonical.json"
    path.write_text(
        json.dumps(
            {
                "records": [
                    {
                        "canonical_id": "LEX-001",
                        "puinave": "AMDA",
                        "espanol": "ejemplo",
                        "ingles": "example",
                    },
                    {
                        "canonical_id": "LEX-002",
                        "puinave": "WAI",
                        "espanol": "agua",
                        "ingles": "",
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def test_SPT_006_detecta_traduccion_ingles_faltante() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-002",
            "espanol": "agua",
            "ingles": "",
        }
    )
    assert any(
        item.resource_type == "translation_en"
        for item in needs
    )


def test_SPT_006_planifica_audio_espanol() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    assert any(item.resource_type == "audio_es" for item in needs)


def test_SPT_006_planifica_audio_ingles() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    assert any(item.resource_type == "audio_en" for item in needs)


def test_SPT_006_planifica_imagen() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    assert any(item.resource_type == "image" for item in needs)


def test_SPT_006_video_es_opcional() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    video = next(
        item for item in needs if item.resource_type == "video"
    )
    assert video.required is False


def test_SPT_006_job_es_idempotente() -> None:
    record = {
        "canonical_id": "LEX-001",
        "espanol": "ejemplo",
        "ingles": "example",
    }
    need = detect_needs(record)[0]
    assert create_job(record, need).job_id == create_job(
        record,
        need,
    ).job_id


def test_SPT_006_planifica_repositorio(tmp_path: Path) -> None:
    records, jobs = plan_repository(_canonical(tmp_path))
    assert len(records) == 2
    assert len(jobs) == 9


def test_SPT_006_mock_no_hace_llamada_externa(
    tmp_path: Path,
) -> None:
    record = {
        "canonical_id": "LEX-001",
        "espanol": "ejemplo",
        "ingles": "example",
    }
    job = create_job(record, detect_needs(record)[0])
    resource = MockEnrichmentProvider().execute(
        job,
        tmp_path / "resources",
    )
    assert resource.metadata["external_call"] is False
    assert resource.metadata["cost_usd"] == 0.0


def test_SPT_006_mock_genera_checksum(tmp_path: Path) -> None:
    record = {
        "canonical_id": "LEX-001",
        "espanol": "ejemplo",
        "ingles": "example",
    }
    job = create_job(record, detect_needs(record)[0])
    resource = MockEnrichmentProvider().execute(
        job,
        tmp_path / "resources",
    )
    assert resource.sha256 is not None
    assert len(resource.sha256) == 64


def test_SPT_006_manifiesto_reproduce_audio_no_video() -> None:
    resources = [
        GeneratedResource(
            resource_id="R1",
            canonical_id="LEX-001",
            resource_type="audio_es",
            status="available",
            uri="audio-es.mp3",
            sha256="a" * 64,
            provider="mock",
            validation_status="technical_valid",
        ),
        GeneratedResource(
            resource_id="R2",
            canonical_id="LEX-001",
            resource_type="video",
            status="available",
            uri="video.mp4",
            sha256="b" * 64,
            provider="mock",
            validation_status="approved",
        ),
    ]
    manifest = build_playback_manifest(
        canonical_id="LEX-001",
        resources=resources,
    )
    assert "audio_es" in manifest.sequence
    assert "video" not in manifest.sequence
    assert manifest.autoplay_video is False


def test_SPT_006_persistencia_idempotente(tmp_path: Path) -> None:
    canonical = _canonical(tmp_path)
    _, jobs = plan_repository(canonical)
    pipeline = EnrichmentPipeline(
        jobs_db=tmp_path / "jobs.sqlite3",
        resources_root=tmp_path / "resources",
        manifests_root=tmp_path / "manifests",
    )
    first = pipeline.persist_jobs(jobs)
    second = pipeline.persist_jobs(jobs)
    assert first == len(jobs)
    assert second == 0


def test_SPT_006_pipeline_genera_manifiestos(
    tmp_path: Path,
) -> None:
    summary = run_pipeline(
        canonical_path=_canonical(tmp_path),
        jobs_db=tmp_path / "jobs.sqlite3",
        resources_root=tmp_path / "resources",
        manifests_root=tmp_path / "manifests",
        limit=2,
    )
    assert summary["records_processed"] == 2
    assert summary["playback_manifests"] == 2
    assert summary["external_calls"] == 0


def test_SPT_006_base_sqlite_registra_recursos(
    tmp_path: Path,
) -> None:
    db = tmp_path / "jobs.sqlite3"
    run_pipeline(
        canonical_path=_canonical(tmp_path),
        jobs_db=db,
        resources_root=tmp_path / "resources",
        manifests_root=tmp_path / "manifests",
    )
    with sqlite3.connect(db) as connection:
        count = connection.execute(
            "SELECT COUNT(*) FROM generated_resources"
        ).fetchone()[0]
    assert count == 9


def test_SPT_006_traduccion_requiere_revision(
    tmp_path: Path,
) -> None:
    record = {
        "canonical_id": "LEX-002",
        "espanol": "agua",
        "ingles": "",
    }
    need = next(
        item for item in detect_needs(record)
        if item.resource_type == "translation_en"
    )
    resource = MockEnrichmentProvider().execute(
        create_job(record, need),
        tmp_path / "resources",
    )
    assert resource.validation_status == "machine_proposed"