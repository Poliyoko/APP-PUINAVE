"""Ejecución controlada del piloto SPT-003C."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from sgoda.automation.adapters.processor import (
    ProcesadorTrabajosMultimedia,
)
from sgoda.automation.adapters.providers import construir_proveedor
from sgoda.automation.adapters.storage import AlmacenamientoLocalRMR
from sgoda.automation.adapters.n8n import PublicadorEventosArchivo
from sgoda.automation.job_queue import ColaTrabajosMultimedia

from .budget import LibroConsumo, estimate_cost
from .circuit_breaker import CircuitBreaker
from .governance import evaluate_activation, load_approval
from .models import RegistroConsumo, ResumenPiloto


def run_pilot(
    *,
    jobs_database: str | Path,
    storage_root: str | Path,
    events_path: str | Path,
    rmr_database: str | Path,
    provider_name: str,
    requested_jobs: int,
    pricing: dict[str, Any],
    approval_path: str | Path | None,
    dry_run: bool,
    ledger_path: str | Path,
    circuit_path: str | Path,
) -> ResumenPiloto:
    queue = ColaTrabajosMultimedia(jobs_database)
    pending = queue.count("pending")
    authorized_jobs = min(requested_jobs, pending)

    job_types = sorted(
        key for key, value in queue.statistics()["by_type"].items()
        if value > 0
    )

    estimated = sum(
        estimate_cost(
            provider=provider_name,
            job_type=job_type,
            units=authorized_jobs,
            pricing=pricing,
        )
        for job_type in job_types
    )

    approval = (
        load_approval(approval_path)
        if approval_path is not None
        and Path(approval_path).is_file()
        else None
    )

    decision = evaluate_activation(
        provider=provider_name,
        requested_jobs=authorized_jobs,
        estimated_cost_usd=estimated,
        job_types=job_types,
        approval=approval,
        dry_run=dry_run,
    )

    breaker = CircuitBreaker(path=circuit_path)

    if not breaker.allow_request():
        return ResumenPiloto(
            provider=provider_name,
            mode="blocked",
            requested_jobs=requested_jobs,
            authorized_jobs=0,
            executed_jobs=0,
            blocked_jobs=requested_jobs,
            estimated_cost_usd=estimated,
            circuit_state=breaker.load()["state"],
            approval_id=approval.approval_id if approval else None,
        )

    if not decision.allowed:
        return ResumenPiloto(
            provider=provider_name,
            mode=decision.mode,
            requested_jobs=requested_jobs,
            authorized_jobs=0,
            executed_jobs=0,
            blocked_jobs=requested_jobs,
            estimated_cost_usd=estimated,
            circuit_state=breaker.load()["state"],
            approval_id=approval.approval_id if approval else None,
        )

    if decision.mode == "dry-run":
        return ResumenPiloto(
            provider=provider_name,
            mode="dry-run",
            requested_jobs=requested_jobs,
            authorized_jobs=authorized_jobs,
            executed_jobs=0,
            blocked_jobs=0,
            estimated_cost_usd=estimated,
            circuit_state=breaker.load()["state"],
            approval_id=approval.approval_id if approval else None,
        )

    provider = construir_proveedor(provider_name)
    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=provider,
        storage=AlmacenamientoLocalRMR(
            root=storage_root,
            rmr_database=rmr_database,
        ),
        events=PublicadorEventosArchivo(events_path),
        worker_id="SPT-003C-pilot",
    )

    summary = processor.process_batch(limit=authorized_jobs)
    executed = int(summary["completed"])

    if int(summary["failed"]) > 0:
        breaker.record_failure()
    else:
        breaker.record_success()

    ledger = LibroConsumo(ledger_path)
    if executed > 0:
        ledger.append(
            RegistroConsumo(
                provider=provider_name,
                job_type="batch",
                units=executed,
                estimated_cost_usd=estimated,
                metadata={
                    "mode": decision.mode,
                    "approval_id": (
                        approval.approval_id if approval else None
                    ),
                },
            )
        )

    return ResumenPiloto(
        provider=provider_name,
        mode=decision.mode,
        requested_jobs=requested_jobs,
        authorized_jobs=authorized_jobs,
        executed_jobs=executed,
        blocked_jobs=requested_jobs - authorized_jobs,
        estimated_cost_usd=estimated,
        circuit_state=breaker.load()["state"],
        approval_id=approval.approval_id if approval else None,
    )


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
        default="artifacts/automation/SPT-003C/media",
    )
    parser.add_argument(
        "--events",
        default=(
            "artifacts/automation/SPT-003C/"
            "multimedia-events.jsonl"
        ),
    )
    parser.add_argument(
        "--rmr",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument("--provider", default="mock")
    parser.add_argument("--limit", type=int, default=2)
    parser.add_argument(
        "--pricing",
        default="config/automation/SPT-003C-pricing-template.json",
    )
    parser.add_argument("--approval")
    parser.add_argument("--live", action="store_true")
    parser.add_argument(
        "--ledger",
        default=(
            "artifacts/automation/SPT-003C/"
            "consumption-ledger.jsonl"
        ),
    )
    parser.add_argument(
        "--circuit",
        default=(
            "artifacts/automation/SPT-003C/"
            "circuit-breaker.json"
        ),
    )
    parser.add_argument(
        "--summary",
        default=(
            "artifacts/automation/SPT-003C/"
            "pilot-summary.json"
        ),
    )
    args = parser.parse_args()

    pricing = json.loads(
        Path(args.pricing).read_text(encoding="utf-8")
    )

    summary = run_pilot(
        jobs_database=args.jobs,
        storage_root=args.storage,
        events_path=args.events,
        rmr_database=args.rmr,
        provider_name=args.provider,
        requested_jobs=args.limit,
        pricing=pricing,
        approval_path=args.approval,
        dry_run=not args.live,
        ledger_path=args.ledger,
        circuit_path=args.circuit,
    )

    summary_path = Path(args.summary)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        json.dumps(
            asdict(summary),
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print("SPT-003C ejecutado correctamente.")
    print(f"Proveedor: {summary.provider}")
    print(f"Modo: {summary.mode}")
    print(f"Solicitados: {summary.requested_jobs}")
    print(f"Autorizados: {summary.authorized_jobs}")
    print(f"Ejecutados: {summary.executed_jobs}")
    print(f"Costo estimado USD: {summary.estimated_cost_usd}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())