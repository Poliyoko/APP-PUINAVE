"""CLI definitivo SGD-114E v1.0.6."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    validation = evaluate_native_ecosystem(args.root)
    result = validation.to_dict()

    json_target = Path(args.output_json)
    md_target = Path(args.output_md)
    json_target.parent.mkdir(parents=True, exist_ok=True)
    md_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(
            result,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    md_target.write_text(
        "\n".join(
            [
                "# SGD-114E — Native Ecosystem Validation",
                "",
                (
                    "- Contrato funcional: "
                    f"{result['version']}"
                ),
                (
                    "- Implementación: "
                    f"{result['implementation_version']}"
                ),
                f"- Resultado: {result['result']}",
                (
                    "- Componentes nativos: "
                    f"{result['native_component_count']}"
                ),
                (
                    "- Hallazgos: "
                    f"{len(result['findings'])}"
                ),
                (
                    "- Términos prohibidos: "
                    f"{result['forbidden_term_count']}"
                ),
                (
                    "- Dependencias propietarias obligatorias: "
                    f"{result['mandatory_proprietary_dependency_count']}"
                ),
                (
                    "- Errores estructurales: "
                    f"{result['structural_error_count']}"
                ),
                "",
                f"Regla: `{result['decision_rule']}`",
                "",
            ]
        ),
        encoding="utf-8",
    )

    print("SGD-114E ejecutado correctamente.")
    print(f"Resultado: {result['result']}")
    print(
        "Contrato funcional: "
        f"{result['version']}"
    )
    print(
        "Implementación: "
        f"{result['implementation_version']}"
    )
    print(
        "Componentes nativos: "
        f"{result['native_component_count']}"
    )
    print(f"Hallazgos: {len(result['findings'])}")
    print(
        "Términos prohibidos: "
        f"{result['forbidden_term_count']}"
    )
    print(
        "Dependencias propietarias obligatorias: "
        f"{result['mandatory_proprietary_dependency_count']}"
    )
    print(
        "Errores estructurales: "
        f"{result['structural_error_count']}"
    )
    print(f"JSON: {json_target}")
    print(f"Markdown: {md_target}")

    return 0 if validation.approved else 2


if __name__ == "__main__":
    raise SystemExit(main())