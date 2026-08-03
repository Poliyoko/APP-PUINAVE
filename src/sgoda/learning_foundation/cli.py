"""CLI SPT-013A."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import FoundationRequest
from .service import LearningEcosystemFoundation


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--operation", default="status")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    result = LearningEcosystemFoundation().execute(
        FoundationRequest(operation=args.operation)
    )

    payload = {
        "operation": result.operation,
        "status": result.status,
        "data": result.data,
        "warnings": list(result.warnings),
        "no_invention": result.no_invention,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print("SPT-013A ejecutado correctamente.")
    print(f"Operación: {result.operation}")
    print(f"Estado: {result.status}")
    print(f"Resultado: {output}")

    return 0 if result.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())