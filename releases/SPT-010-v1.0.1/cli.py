"""CLI robusta de SPT-010.

Compatible con Windows PowerShell, PowerShell 7, Linux y CI/CD.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .health import repository_health
from .models import PlatformRequest
from .runtime import build_runtime


def _load_payload(
    raw_payload: str,
    payload_file: str | None = None,
) -> dict[str, Any]:
    """Carga un payload JSON desde texto o archivo.

    Se prefiere payload_file porque evita alteraciones de comillas
    producidas por el shell. La reparación de comillas se conserva
    únicamente como compatibilidad defensiva.
    """

    if payload_file:
        payload_path = Path(payload_file)

        if not payload_path.is_file():
            raise ValueError(
                f"No se encontró el archivo de payload: {payload_path}"
            )

        raw_payload = payload_path.read_text(
            encoding="utf-8-sig"
        )

    raw_payload = str(raw_payload or "{}").strip()

    candidates = (
        raw_payload,
        raw_payload.replace('\\"', '"'),
        raw_payload.replace("'", '"'),
        raw_payload.replace('\\"', '"').replace("'", '"'),
    )

    last_error: json.JSONDecodeError | None = None

    for candidate in dict.fromkeys(candidates):
        try:
            payload = json.loads(candidate)

        except json.JSONDecodeError as error:
            last_error = error
            continue

        if not isinstance(payload, dict):
            raise ValueError(
                "El payload debe ser un objeto JSON."
            )

        return payload

    raise ValueError(
        "El payload no contiene JSON válido."
    ) from last_error


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--operation", required=True)
    parser.add_argument("--payload", default="{}")
    parser.add_argument("--payload-file")
    parser.add_argument("--session", default="anonymous")
    parser.add_argument("--language", default="es")
    parser.add_argument("--node")
    parser.add_argument("--output")
    parser.add_argument("--root", default=".")
    args = parser.parse_args()

    payload = _load_payload(
        args.payload,
        args.payload_file,
    )
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