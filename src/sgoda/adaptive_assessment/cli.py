"""CLI de SPT-015."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import AssessmentCommand
from .service import AdaptiveAssessmentEngine


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

    engine = AdaptiveAssessmentEngine()

    for item in request.get("items", []):
        engine.execute(
            AssessmentCommand(
                operation="upsert_item",
                payload=dict(item),
            )
        )

    for attempt in request.get("attempts", []):
        engine.execute(
            AssessmentCommand(
                operation="submit_answer",
                payload=dict(attempt),
            )
        )

    response = engine.execute(
        AssessmentCommand(
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

    print("SPT-015 ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())