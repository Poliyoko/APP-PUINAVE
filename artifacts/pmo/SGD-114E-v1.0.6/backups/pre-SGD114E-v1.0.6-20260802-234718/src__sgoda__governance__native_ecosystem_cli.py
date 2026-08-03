"""CLI SGD-114E v1.0.5."""

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

    criteria = result["criteria"]

    md_target.write_text(
        "\n".join(
            [
                "# SGD-114E — Native Ecosystem Validation",
                "",
                f"- Versión: {result['version']}",
                f"- Resultado: {result['result']}",
                (
                    "- Componentes nativos: "
                    f"{result['native_component_count']}"
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
                "## Criterios",
                "",
                (
                    "- Existen componentes nativos: "
                    f"{criteria['has_native_components']}"
                ),
                (
                    "- Sin términos prohibidos: "
                    f"{criteria['no_forbidden_terms']}"
                ),
                (
                    "- Sin dependencias propietarias obligatorias: "
                    f"{criteria['no_mandatory_proprietary_dependencies']}"
                ),
                (
                    "- Sin errores estructurales: "
                    f"{criteria['no_structural_errors']}"
                ),
                "",
                "## Compatibilidad",
                "",
                "- Acceso por atributos: habilitado",
                "- Acceso como diccionario: habilitado",
                "- Conversión `to_dict()`: habilitada",
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
        "Componentes nativos: "
        f"{result['native_component_count']}"
    )
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
    print("Compatibilidad histórica: HABILITADA")
    print(f"JSON: {json_target}")
    print(f"Markdown: {md_target}")

    return 0 if validation.approved else 2


if __name__ == "__main__":
    raise SystemExit(main())