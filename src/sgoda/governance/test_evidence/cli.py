"""CLI de SGD-114F."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .junit_parser import parse_junit_report
from .synchronizer import (
    synchronize_evidence_file,
    write_summary,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--junit", required=True)
    parser.add_argument("--component", required=True)
    parser.add_argument("--scope", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    parser.add_argument("--evidence")
    parser.add_argument(
        "--evidence-key",
        default="specific_tests",
    )
    args = parser.parse_args()

    summary = parse_junit_report(
        args.junit,
        component=args.component,
        scope=args.scope,
    )
    write_summary(
        summary,
        args.output_json,
        args.output_md,
    )

    if args.evidence:
        synchronize_evidence_file(
            args.evidence,
            summary,
            evidence_key=args.evidence_key,
        )

    print("SGD-114F ejecutado correctamente.")
    print(f"Componente: {summary.component}")
    print(f"Alcance: {summary.scope}")
    print(f"Ejecutadas: {summary.executed}")
    print(f"Aprobadas: {summary.passed}")
    print(f"Fallidas: {summary.failures}")
    print(f"Errores: {summary.errors}")
    print(f"Omitidas: {summary.skipped}")
    print(f"Resultado: {'APROBADO' if summary.approved else 'NO APROBADO'}")
    print(f"JSON: {Path(args.output_json)}")
    print(f"Markdown: {Path(args.output_md)}")

    return 0 if summary.approved else 2


if __name__ == "__main__":
    raise SystemExit(main())