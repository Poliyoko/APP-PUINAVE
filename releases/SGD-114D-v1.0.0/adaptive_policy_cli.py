"""CLI de SGD-114D."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .adaptive_policy_engine import evaluate_adaptive_policy


def _payload(result) -> dict:
    return {
        "policy": "SGD-114D",
        "version": "1.0.0",
        "increment_code": result.increment_code,
        "approved": result.approved,
        "exit_code": result.exit_code,
        "evidence_path": result.evidence_path,
        "release_path": result.release_path,
        "results": [
            {
                "rule_code": item.rule_code,
                "name": item.name,
                "passed": item.passed,
                "blocking": item.blocking,
                "message": item.message,
                "remediation": item.remediation,
                "evidence": list(item.evidence),
                "metadata": item.metadata,
            }
            for item in result.results
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--increment", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    result = evaluate_adaptive_policy(
        args.root,
        args.increment,
    )
    payload = _payload(result)

    json_path = Path(args.output_json)
    md_path = Path(args.output_md)

    json_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.parent.mkdir(parents=True, exist_ok=True)

    json_path.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# SGD-114D — Resultado adaptativo",
        "",
        f"- Incremento: {result.increment_code}",
        f"- Aprobado: {result.approved}",
        f"- Código de salida: {result.exit_code}",
        f"- Evidencia: {result.evidence_path}",
        f"- Release: {result.release_path}",
        "",
        "## Reglas",
        "",
    ]

    for item in result.results:
        lines.extend(
            [
                f"### {item.rule_code} — {item.name}",
                "",
                f"- Aprobada: {item.passed}",
                f"- Bloqueante: {item.blocking}",
                f"- Mensaje: {item.message}",
                f"- Remediación: {item.remediation}",
                "",
            ]
        )

    md_path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )

    print("Adaptive Institutional Policy Engine ejecutado.")
    print("Política: SGD-114D 1.0.0")
    print(f"Incremento: {result.increment_code}")
    print(
        "Resultado: "
        + ("APROBADO" if result.approved else "NO APROBADO")
    )
    print(f"Código de salida: {result.exit_code}")
    print(f"JSON: {json_path}")
    print(f"Markdown: {md_path}")

    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())