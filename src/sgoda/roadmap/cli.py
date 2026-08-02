"""CLI definitiva de SGD-116."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .generator import generate_roadmap


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--output",
        default="artifacts/roadmap/SGD-116",
    )
    args = parser.parse_args()

    paths = generate_roadmap(
        args.root,
        args.output,
    )

    validation = json.loads(
        Path(paths["validation"]).read_text(
            encoding="utf-8"
        )
    )

    print("SGD-116 ejecutado correctamente.")
    print(f"Componentes: {validation['component_count']}")
    print(
        "Validación: "
        f"{'APROBADA' if validation['passed'] else 'NO APROBADA'}"
    )
    print(
        "Dependencias faltantes: "
        f"{len(validation['missing_dependencies'])}"
    )
    print(
        "Dependencias históricas resueltas: "
        f"{len(validation['historical_dependencies'])}"
    )
    print(
        "Rutas rotas: "
        f"{len(validation['broken_paths'])}"
    )
    print(
        "Ciclos: "
        f"{len(validation['dependency_cycles'])}"
    )
    print(f"Roadmap: {paths['roadmap']}")

    if not validation["passed"]:
        if validation["missing_dependencies"]:
            print("Detalle de dependencias faltantes:")
            for item in validation["missing_dependencies"]:
                print(
                    f"  {item['source']} -> "
                    f"{item['target']}"
                )

        if validation["broken_paths"]:
            print("Detalle de rutas rotas:")
            for item in validation["broken_paths"]:
                print(f"  {item}")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())