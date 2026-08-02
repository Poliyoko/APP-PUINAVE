"""CLI operativa de SPT-011."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import OperationalRequest
from .service import OperationalPlatformService
from .settings import OperationalSettings


def _load_json(raw: str) -> dict:
    payload = json.loads(raw)

    if not isinstance(payload, dict):
        raise ValueError(
            "El payload debe ser un objeto JSON."
        )

    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--settings", required=True)
    parser.add_argument("--rlb", required=True)
    parser.add_argument("--media")
    parser.add_argument("--operation", required=True)
    parser.add_argument("--payload", default="{}")
    parser.add_argument("--entry")
    parser.add_argument("--session", default="anonymous")
    parser.add_argument("--language", default="es")
    parser.add_argument("--output")
    args = parser.parse_args()

    service = OperationalPlatformService(
        OperationalSettings.from_json(args.settings)
    )
    service.load_sources(
        args.rlb,
        args.media,
    )

    response = service.execute(
        OperationalRequest(
            operation=args.operation,
            payload=_load_json(args.payload),
            session_id=args.session,
            language=args.language,
            entry_id=args.entry,
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "sources": list(response.sources),
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
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