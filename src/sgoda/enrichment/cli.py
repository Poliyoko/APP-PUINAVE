"""CLI de SPT-006."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import run_pipeline


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--canonical",
        default=(
            "artifacts/rlb/SPT-001B-P08/"
            "canonical-repository-v1.0.0.json"
        ),
    )
    parser.add_argument(
        "--jobs-db",
        default=(
            "artifacts/enrichment/SPT-006/"
            "enrichment-jobs.sqlite3"
        ),
    )
    parser.add_argument(
        "--resources",
        default=(
            "artifacts/enrichment/SPT-006/"
            "mock-resources"
        ),
    )
    parser.add_argument(
        "--manifests",
        default=(
            "artifacts/enrichment/SPT-006/"
            "playback-manifests"
        ),
    )
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument(
        "--summary",
        default=(
            "artifacts/enrichment/SPT-006/"
            "pipeline-summary.json"
        ),
    )
    args = parser.parse_args()

    summary = run_pipeline(
        canonical_path=args.canonical,
        jobs_db=args.jobs_db,
        resources_root=args.resources,
        manifests_root=args.manifests,
        limit=args.limit,
    )

    output = Path(args.summary)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("SPT-006 ejecutado correctamente.")
    print(f"Registros: {summary['records_processed']}")
    print(f"Trabajos: {summary['jobs_planned']}")
    print(
        "Recursos simulados: "
        f"{summary['resources_generated_mock']}"
    )
    print(f"Manifiestos: {summary['playback_manifests']}")
    print("Llamadas externas: 0")
    print("Costo USD: 0.0")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())