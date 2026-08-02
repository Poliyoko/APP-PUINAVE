"""Serialización e informes de SGD-114C."""

from __future__ import annotations

import json
from pathlib import Path

from .policy_models import PolicyEvaluation


def evaluation_to_dict(
    evaluation: PolicyEvaluation,
) -> dict:
    results = []

    for item in evaluation.results:
        results.append(
            {
                "rule": item.rule.code,
                "name": item.rule.name,
                "category": item.rule.category,
                "severity": item.rule.severity.value,
                "status": item.status.value,
                "passed": item.passed,
                "blocking": item.blocking,
                "message": item.message,
                "evidence": list(item.evidence),
                "remediation": item.remediation,
                "details": item.details,
            }
        )

    return {
        "policy_code": evaluation.policy_code,
        "policy_version": evaluation.policy_version,
        "increment": evaluation.increment,
        "approved": evaluation.approved,
        "exit_code": evaluation.exit_code,
        "generated_at_utc": evaluation.generated_at_utc,
        "blocking_rules": [
            item.rule.code
            for item in evaluation.blocking_rules
        ],
        "failed_rules": [
            item.rule.code
            for item in evaluation.failed_rules
        ],
        "results": results,
    }


def write_reports(
    evaluation: PolicyEvaluation,
    json_path: str | Path,
    markdown_path: str | Path,
) -> None:
    payload = evaluation_to_dict(evaluation)

    json_target = Path(json_path)
    markdown_target = Path(markdown_path)

    json_target.parent.mkdir(parents=True, exist_ok=True)
    markdown_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    lines = [
        f"# {evaluation.policy_code} — {evaluation.increment}",
        "",
        f"- Versión: {evaluation.policy_version}",
        f"- Resultado: {'APROBADO' if evaluation.approved else 'NO APROBADO'}",
        f"- Código de salida: {evaluation.exit_code}",
        f"- Generado: {evaluation.generated_at_utc}",
        "",
        "## Reglas",
        "",
    ]

    for item in evaluation.results:
        lines.extend(
            [
                f"### {item.rule.code} — {item.rule.name}",
                "",
                f"- Categoría: {item.rule.category}",
                f"- Severidad: {item.rule.severity.value}",
                f"- Estado: {item.status.value}",
                f"- Mensaje: {item.message}",
                f"- Evidencia: {', '.join(item.evidence) or 'N/A'}",
                f"- Corrección: {item.remediation or 'N/A'}",
                "",
            ]
        )

    markdown_target.write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
    )