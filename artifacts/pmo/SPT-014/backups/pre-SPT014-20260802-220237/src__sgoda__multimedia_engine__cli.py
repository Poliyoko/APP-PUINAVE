"""CLI del Motor Multimedia Inteligente."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import MultimediaCommand
from .service import IntelligentMultimediaEngine


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request-file", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    request = json.loads(
        Path(args.request_file).read_text(
            encoding="utf-8-sig"
        )
    )

    engine = IntelligentMultimediaEngine()
    preload = request.get("preload", [])

    for item in preload:
        engine.execute(
            MultimediaCommand(
                operation="upsert",
                payload=dict(item),
            )
        )

    response = engine.execute(
        MultimediaCommand(
            operation=str(request["operation"]),
            payload=dict(request.get("payload") or {}),
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
    }

    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            result,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    print("SPT-014 ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())