"""CLI de SPT-006A v0.2.0."""

from __future__ import annotations

import argparse
import json

from .engine import FreeLocalLanguageEngine
from .licensing import approved_models


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    diagnostic = sub.add_parser("diagnostic")
    diagnostic.add_argument(
        "--allowlist",
        default=(
            "config/language_engine/"
            "SPT-006A-approved-free-models.json"
        ),
    )
    diagnostic.add_argument(
        "--models-root",
        default="models/language_engine",
    )
    diagnostic.add_argument(
        "--output",
        default=(
            "artifacts/language_engine/SPT-006A/"
            "diagnostic.json"
        ),
    )

    models = sub.add_parser("approved-models")
    models.add_argument(
        "--allowlist",
        default=(
            "config/language_engine/"
            "SPT-006A-approved-free-models.json"
        ),
    )
    models.add_argument("--purpose")
    models.add_argument("--locale")

    args = parser.parse_args()

    if args.command == "approved-models":
        payload = approved_models(
            args.allowlist,
            purpose=args.purpose,
            locale=args.locale,
        )
        print(
            json.dumps(
                [
                    {
                        "model_id": item.model_id,
                        "purpose": item.purpose,
                        "locale": item.locale,
                        "provider": item.provider,
                    }
                    for item in payload
                ],
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    engine = FreeLocalLanguageEngine(
        allowlist_path=args.allowlist,
        models_root=args.models_root,
    )
    path = engine.publish_diagnostic(args.output)

    print("SPT-006A diagnóstico completado.")
    print(f"Evidencia: {path}")
    print("Servicios de pago: DESHABILITADOS.")
    print("Claves API: NO REQUERIDAS.")
    print("Política de licencia desconocida: BLOQUEAR.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())