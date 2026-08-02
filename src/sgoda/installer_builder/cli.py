from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .generator import generate_package
from .models import IncrementSpec


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    new = sub.add_parser("new")
    new.add_argument("--code", required=True)
    new.add_argument("--name", required=True)
    new.add_argument("--type", default="technology_increment")
    new.add_argument("--version", default="0.1.0")
    new.add_argument("--description", default="")
    new.add_argument("--output", default="generated/installers")
    new.add_argument("--force", action="store_true")
    new.add_argument("--preview", action="store_true")
    new.add_argument(
        "--result",
        default="artifacts/installer_builder/SIB-001/last-generation.json",
    )
    args = parser.parse_args()
    package = generate_package(
        output_root=args.output,
        spec=IncrementSpec(
            code=args.code,
            name=args.name,
            component_type=args.type,
            version=args.version,
            description=args.description,
        ),
        force=args.force,
        preview=args.preview,
    )
    result = Path(args.result)
    result.parent.mkdir(parents=True, exist_ok=True)
    result.write_text(
        json.dumps({k: str(v) for k, v in asdict(package).items()}, indent=2) + "\n",
        encoding="utf-8",
    )
    print("SIB-001 ejecutado correctamente.")
    print(f"Incremento: {args.code.upper()}")
    print(f"Destino: {package.root}")
    print(f"Preview: {args.preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())