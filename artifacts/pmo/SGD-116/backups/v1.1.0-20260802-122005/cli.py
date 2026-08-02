"""CLI institucional de SGD-116."""

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

    paths = generate_roadmap(args.root, args.output)

    validation = json.loads(
        Path(paths["validation"]).read_text(
            encoding="utf-8"
        )
    )

    print("SGD-116 ejecutado correctamente.")
    print(
        "Componentes: "
        f"{validation['component_count']}"
    )
    print(
        "Validación: "
        f"{'APROBADA' if validation['passed'] else 'NO APROBADA'}"
    )
    print(f"Roadmap: {paths['roadmap']}")
    print(f"Dashboard: dashboard/ecosystem-roadmap.json")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())