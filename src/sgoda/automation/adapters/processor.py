"""Procesador institucional de trabajos SPT-003A."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from sgoda.automation.job_queue import ColaTrabajosMultimedia

from .contracts import SolicitudProveedor
from .n8n import PublicadorEventosArchivo
from .providers import construir_proveedor
from .storage import AlmacenamientoLocalRMR


class ProcesadorTrabajosMultimedia:
    def __init__(
        self,
        *,
        queue: ColaTrabajosMultimedia,
        provider: Any,
        storage: AlmacenamientoLocalRMR,
        events: PublicadorEventosArchivo,
        worker_id: str = "SPT-003B-worker",
    ) -> None:
        self.queue = queue
        self.provider = provider
        self.storage = storage
        self.events = events
        self.worker_id = worker_id

    def process_batch(
        self,
        limit: int = 10,
    ) -> dict[str, int]:
        leased = self.queue.lease(
            worker_id=self.worker_id,
            limit=limit,
        )

        summary = {
            "leased": len(leased),
            "completed": 0,
            "retried": 0,
            "failed": 0,
        }

        for job in leased:
            request = SolicitudProveedor(
                job_id=job.job_id,
                job_type=job.job_type,
                resource_id=job.resource_id,
                oda_id=job.oda_id,
                language=job.language,
                payload=job.payload,
            )

            result = self.provider.execute(request)

            if not result.success:
                self.queue.fail(
                    job.job_id,
                    result.error or "Proveedor sin detalle de error",
                    retry_delay_seconds=0,
                )

                state = (
                    "failed"
                    if self.queue.count("failed") > summary["failed"]
                    else "retry"
                )

                if state == "failed":
                    summary["failed"] += 1
                else:
                    summary["retried"] += 1

                self.events.publish(
                    event_type="MultimediaJobFailed",
                    payload={
                        "job_id": job.job_id,
                        "resource_id": job.resource_id,
                        "provider": result.provider,
                        "error": result.error,
                        "state": state,
                    },
                )
                continue

            if result.media_bytes is None or result.media_type is None:
                self.queue.fail(
                    job.job_id,
                    "El proveedor no devolvió contenido multimedia.",
                    retry_delay_seconds=0,
                )
                summary["retried"] += 1
                continue

            stored = self.storage.store(
                resource_id=job.resource_id,
                media_bytes=result.media_bytes,
                media_type=result.media_type,
                metadata={
                    **result.metadata,
                    "provider": result.provider,
                    "external_id": result.external_id,
                    "job_id": job.job_id,
                },
            )

            completion = {
                "provider": result.provider,
                "external_id": result.external_id,
                "storage": asdict(stored),
            }

            self.queue.complete(job.job_id, completion)
            summary["completed"] += 1

            self.events.publish(
                event_type="MultimediaJobCompleted",
                payload={
                    "job_id": job.job_id,
                    "resource_id": job.resource_id,
                    "provider": result.provider,
                    "storage": asdict(stored),
                },
            )

        return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--jobs",
        default=(
            "artifacts/automation/SPT-003A/"
            "multimedia-jobs.sqlite3"
        ),
    )
    parser.add_argument(
        "--storage",
        default="artifacts/automation/SPT-003B/media",
    )
    parser.add_argument(
        "--events",
        default=(
            "artifacts/automation/SPT-003B/"
            "multimedia-events.jsonl"
        ),
    )
    parser.add_argument(
        "--rmr",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument("--provider", default="mock")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument(
        "--summary",
        default=(
            "artifacts/automation/SPT-003B/"
            "processing-summary.json"
        ),
    )
    args = parser.parse_args()

    queue = ColaTrabajosMultimedia(args.jobs)
    provider = construir_proveedor(args.provider)
    storage = AlmacenamientoLocalRMR(
        root=args.storage,
        rmr_database=args.rmr,
    )
    events = PublicadorEventosArchivo(args.events)

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=provider,
        storage=storage,
        events=events,
    )

    summary = processor.process_batch(limit=args.limit)

    summary_path = Path(args.summary)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        json.dumps(
            summary,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print("SPT-003B ejecutado correctamente.")
    print(f"Proveedor: {args.provider}")
    print(f"Leased: {summary['leased']}")
    print(f"Completados: {summary['completed']}")
    print(f"Reintentos: {summary['retried']}")
    print(f"Fallidos: {summary['failed']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())