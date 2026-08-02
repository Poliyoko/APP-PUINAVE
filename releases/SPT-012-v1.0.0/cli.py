"""CLI de SPT-012."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .digital_dictionary import DigitalDictionary
from .media_library import MediaLibrary
from .models import LearningRequest
from .service import LearningPlatformService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dictionary", required=True)
    parser.add_argument("--media", required=True)
    parser.add_argument("--request-file", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    dictionary = DigitalDictionary()
    dictionary.load(args.dictionary)

    media = MediaLibrary()
    media.load(args.media)

    request_payload = json.loads(
        Path(args.request_file).read_text(
            encoding="utf-8-sig"
        )
    )

    service = LearningPlatformService(
        dictionary,
        media,
    )
    response = service.execute(
        LearningRequest(
            operation=str(request_payload["operation"]),
            learner_id=str(
                request_payload.get(
                    "learner_id",
                    "anonymous",
                )
            ),
            language=str(
                request_payload.get("language", "es")
            ),
            entry_id=request_payload.get("entry_id"),
            payload=dict(request_payload.get("payload") or {}),
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

    print("SPT-012 ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())