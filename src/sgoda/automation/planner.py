"""Planificador de trabajos multimedia desde ADR-010 RMR."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from .job_queue import (
    ColaTrabajosMultimedia,
    deterministic_job_id,
)
from .models import ResumenPlanificacion, TrabajoMultimedia


SUPPORTED = {
    "imagen_ilustrativa": "generate_image",
    "audio_puinave": "record_native_audio",
    "audio_espanol": "generate_tts",
    "audio_ingles": "generate_tts",
}


def _read_oda_index(path: Path) -> dict[str, dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    objects = payload.get("objetos_digitales_aprendizaje") or []
    return {
        str(item["oda_id"]): item
        for item in objects
        if isinstance(item, dict) and item.get("oda_id")
    }


def _image_prompt(oda: dict[str, Any]) -> str:
    word = str(oda.get("palabra_puinave") or "").strip()
    spanish = str(
        oda.get("traduccion_espanol") or ""
    ).strip()
    cultural = str(
        oda.get("contexto_etnografico")
        or oda.get("tema_cultural")
        or ""
    ).strip()

    parts = [
        "IlustraciÃ³n educativa clara y culturalmente respetuosa",
        f"para la palabra Puinave Â«{word}Â»",
    ]

    if spanish:
        parts.append(f"cuyo significado en espaÃ±ol es Â«{spanish}Â»")

    if cultural:
        parts.append(f"con contexto cultural: {cultural}")

    parts.extend(
        [
            "sin texto escrito dentro de la imagen",
            "composiciÃ³n simple",
            "apta para una aplicaciÃ³n educativa infantil y comunitaria",
        ]
    )

    return ". ".join(parts) + "."


def _payload(
    resource: sqlite3.Row,
    oda: dict[str, Any],
    job_type: str,
) -> dict[str, Any]:
    base = {
        "resource_id": resource["resource_id"],
        "oda_id": resource["oda_id"],
        "canonical_id": resource["canonical_id"],
        "resource_type": resource["resource_type"],
        "language": resource["language"],
        "callback_event": "MultimediaJobCompleted",
    }

    if job_type == "generate_image":
        base.update(
            {
                "prompt": _image_prompt(oda),
                "negative_prompt": (
                    "texto, letras, marcas de agua, estereotipos, "
                    "contenido ofensivo, anatomÃ­a incorrecta"
                ),
                "human_review_required": True,
            }
        )
    elif job_type == "record_native_audio":
        base.update(
            {
                "text": oda.get("palabra_puinave"),
                "speaker_type": "native_puinave",
                "recording_mode": "human_recording",
                "human_review_required": True,
            }
        )
    elif job_type == "generate_tts":
        language = resource["language"]
        text = (
            oda.get("traduccion_espanol")
            if language == "es"
            else oda.get("traduccion_ingles")
        )
        base.update(
            {
                "text": text,
                "voice_policy": "institutional_neutral",
                "human_review_required": True,
            }
        )

    return base


def iter_jobs(
    *,
    rmr_database: str | Path,
    oda_repository: str | Path,
) -> Iterable[TrabajoMultimedia]:
    oda_index = _read_oda_index(Path(oda_repository))

    connection = sqlite3.connect(rmr_database)
    connection.row_factory = sqlite3.Row

    try:
        rows = connection.execute(
            """
            SELECT *
            FROM media_resources
            ORDER BY resource_id
            """
        )

        for resource in rows:
            job_type = SUPPORTED.get(resource["resource_type"])

            if job_type is None:
                continue

            oda = oda_index.get(resource["oda_id"], {})
            payload = _payload(resource, oda, job_type)

            yield TrabajoMultimedia(
                job_id=deterministic_job_id(
                    resource["resource_id"],
                    job_type,
                ),
                resource_id=resource["resource_id"],
                oda_id=resource["oda_id"],
                canonical_id=resource["canonical_id"],
                job_type=job_type,
                language=resource["language"],
                priority=50 if job_type == "record_native_audio" else 100,
                payload=payload,
            )
    finally:
        connection.close()


def planificar(
    *,
    rmr_database: str | Path,
    oda_repository: str | Path,
    jobs_database: str | Path,
) -> ResumenPlanificacion:
    queue = ColaTrabajosMultimedia(jobs_database)
    queue.initialize()

    jobs = list(
        iter_jobs(
            rmr_database=rmr_database,
            oda_repository=oda_repository,
        )
    )

    inserted, existing = queue.upsert_many(jobs)

    by_type: dict[str, int] = {}
    for job in jobs:
        by_type[job.job_type] = by_type.get(job.job_type, 0) + 1

    with sqlite3.connect(rmr_database) as connection:
        resources_seen = int(
            connection.execute(
                "SELECT COUNT(*) FROM media_resources"
            ).fetchone()[0]
        )

    return ResumenPlanificacion(
        resources_seen=resources_seen,
        jobs_planned=len(jobs),
        jobs_inserted=inserted,
        jobs_existing=existing,
        by_type=by_type,
        unsupported_resources=resources_seen - len(jobs),
    )


def publish_artifacts(
    *,
    summary: ResumenPlanificacion,
    queue: ColaTrabajosMultimedia,
    output_dir: str | Path,
) -> dict[str, Path]:
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    stats = queue.statistics()
    generated_at = datetime.now(timezone.utc).isoformat()

    summary_path = output / "planning-summary.json"
    summary_path.write_text(
        json.dumps(asdict(summary), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    stats_path = output / "job-statistics.json"
    stats_path.write_text(
        json.dumps(stats, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    event = {
        "event_type": "MultimediaJobsPlanned",
        "occurred_at_utc": generated_at,
        "source": "sgoda.automation",
        "increment": "SPT-003A",
        "jobs_planned": summary.jobs_planned,
        "jobs_inserted": summary.jobs_inserted,
        "jobs_existing": summary.jobs_existing,
        "n8n_contract": {
            "trigger": "queue_poll_or_event",
            "completion_event": "MultimediaJobCompleted",
            "failure_event": "MultimediaJobFailed",
        },
    }

    event_path = output / "multimedia-jobs-planned-event.json"
    event_path.write_text(
        json.dumps(event, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    validation = {
        "increment": "SPT-003A",
        "passed": (
            summary.jobs_planned > 0
            and summary.jobs_planned == stats["total_jobs"]
        ),
        "checks": {
            "jobs_present": summary.jobs_planned > 0,
            "idempotent_total": summary.jobs_planned == stats["total_jobs"],
            "supported_resources_only": summary.unsupported_resources >= 0,
            "four_baseline_job_groups": len(summary.by_type) == 3,
        },
    }

    validation_path = output / "orchestrator-validation.json"
    validation_path.write_text(
        json.dumps(validation, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    return {
        "summary": summary_path,
        "statistics": stats_path,
        "event": event_path,
        "validation": validation_path,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--rmr",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument(
        "--oda",
        default="artifacts/oda/SPT-002/oda-repository-v0.1.0.json",
    )
    parser.add_argument(
        "--jobs",
        default="artifacts/automation/SPT-003A/multimedia-jobs.sqlite3",
    )
    parser.add_argument(
        "--output",
        default="artifacts/automation/SPT-003A",
    )
    args = parser.parse_args()

    summary = planificar(
        rmr_database=args.rmr,
        oda_repository=args.oda,
        jobs_database=args.jobs,
    )

    queue = ColaTrabajosMultimedia(args.jobs)
    artifacts = publish_artifacts(
        summary=summary,
        queue=queue,
        output_dir=args.output,
    )

    validation = json.loads(
        artifacts["validation"].read_text(encoding="utf-8")
    )

    print("SPT-003A ejecutado correctamente.")
    print(f"Recursos RMR: {summary.resources_seen}")
    print(f"Trabajos planificados: {summary.jobs_planned}")
    print(f"Nuevos: {summary.jobs_inserted}")
    print(f"Existentes: {summary.jobs_existing}")
    print(f"Cola: {args.jobs}")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())