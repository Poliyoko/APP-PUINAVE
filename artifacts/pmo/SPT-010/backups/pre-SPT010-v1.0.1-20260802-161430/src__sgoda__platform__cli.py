"""CLI de SPT-010."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .health import repository_health
from .models import PlatformRequest
from .runtime import build_runtime


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--operation", required=True)
    parser.add_argument("--payload", default="{}")
    parser.add_argument("--session", default="anonymous")
    parser.add_argument("--language", default="es")
    parser.add_argument("--node")
    parser.add_argument("--output")
    parser.add_argument("--root", default=".")
    args = parser.parse_args()

    payload = json.loads(args.payload)
    runtime = build_runtime(args.graph)

    response = runtime.execute(
        PlatformRequest(
            operation=args.operation,
            payload=payload,
            session_id=args.session,
            language=args.language,
            context_node_id=args.node,
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "sources": list(response.sources),
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
        "health": repository_health(args.root),
    }

    serialized = json.dumps(
        result,
        indent=2,
        ensure_ascii=False,
    )

    if args.output:
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            serialized + "\n",
            encoding="utf-8",
        )
    else:
        print(serialized)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())