"""Sincronización de evidencias institucionales."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import TestEvidenceSummary


def write_summary(
    summary: TestEvidenceSummary,
    json_path: str | Path,
    markdown_path: str | Path,
) -> None:
    json_target = Path(json_path)
    markdown_target = Path(markdown_path)
    json_target.parent.mkdir(parents=True, exist_ok=True)
    markdown_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(
            summary.to_dict(),
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    markdown_target.write_text(
        "\n".join(
            [
                f"# Evidencia de pruebas — {summary.component}",
                "",
                f"- Alcance: {summary.scope}",
                f"- Ejecutadas: {summary.executed}",
                f"- Aprobadas: {summary.passed}",
                f"- Fallidas: {summary.failures}",
                f"- Errores: {summary.errors}",
                f"- Omitidas: {summary.skipped}",
                (
                    "- Duración: "
                    f"{summary.duration_seconds:.4f} segundos"
                ),
                (
                    "- Resultado: "
                    + ("APROBADO" if summary.approved else "NO APROBADO")
                ),
                f"- Fuente: `{summary.source_report}`",
                "",
            ]
        ),
        encoding="utf-8",
    )


def synchronize_evidence_file(
    evidence_path: str | Path,
    summary: TestEvidenceSummary,
    *,
    evidence_key: str = "specific_tests",
) -> dict[str, Any]:
    target = Path(evidence_path)

    if target.exists():
        payload = json.loads(
            target.read_text(encoding="utf-8-sig")
        )
    else:
        payload = {}

    payload[evidence_key] = {
        "executed": summary.executed,
        "passed": summary.passed,
        "failures": summary.failures,
        "errors": summary.errors,
        "skipped": summary.skipped,
        "duration_seconds": summary.duration_seconds,
        "approved": summary.approved,
        "source_report": summary.source_report,
    }
    payload[
        f"{evidence_key}_count"
    ] = summary.executed
    payload[
        f"{evidence_key}_passed"
    ] = summary.passed
    payload[
        f"{evidence_key}_synchronized"
    ] = True

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    return payload