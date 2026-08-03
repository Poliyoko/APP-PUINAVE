"""CLI de SGD-114E."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    result = evaluate_native_ecosystem(args.root)

    payload = {
        "policy": "SGD-114E",
        "version": "1.0.2",
        "approved": result.approved,
        "exit_code": result.exit_code,
        "component_count": result.component_count,
        "forbidden_term_count": (
            result.forbidden_term_count
        ),
        "proprietary_dependency_count": (
            result.proprietary_dependency_count
        ),
        "findings": [
            {
                "rule_code": item.rule_code,
                "passed": item.passed,
                "blocking": item.blocking,
                "message": item.message,
                "path": item.path,
                "remediation": item.remediation,
            }
            for item in result.findings
        ],
    }

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
        "# SGD-114E — Evaluación del ecosistema nativo",
        "",
        f"- Aprobado: {result.approved}",
        f"- Código de salida: {result.exit_code}",
        f"- Componentes nativos: {result.component_count}",
        (
            "- Términos prohibidos: "
            f"{result.forbidden_term_count}"
        ),
        (
            "- Dependencias propietarias obligatorias: "
            f"{result.proprietary_dependency_count}"
        ),
        "",
        "## Hallazgos",
        "",
    ]

    for item in result.findings:
        lines.extend(
            [
                f"### {item.rule_code}",
                "",
                f"- Aprobado: {item.passed}",
                f"- Bloqueante: {item.blocking}",
                f"- Mensaje: {item.message}",
                f"- Ruta: {item.path}",
                f"- Remediación: {item.remediation}",
                "",
            ]
        )

    md_path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )

    print("SGD-114E ejecutado correctamente.")
    print(
        "Resultado: "
        + ("APROBADO" if result.approved else "NO APROBADO")
    )
    print(f"Componentes nativos: {result.component_count}")
    print(
        "Términos prohibidos: "
        f"{result.forbidden_term_count}"
    )
    print(
        "Dependencias propietarias obligatorias: "
        f"{result.proprietary_dependency_count}"
    )
    print(f"JSON: {json_path}")
    print(f"Markdown: {md_path}")

    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())