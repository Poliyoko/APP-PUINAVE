"""CLI del Sistema de Identidad Cultural Configurable."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .exporter import export_api, export_flutter, export_web
from .repository import IdentityRepository
from .service import IdentityService


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    show = subparsers.add_parser("show")
    show.add_argument(
        "--repository",
        default="config/identity/SPT-005-identities.json",
    )

    export = subparsers.add_parser("export")
    export.add_argument(
        "--repository",
        default="config/identity/SPT-005-identities.json",
    )
    export.add_argument(
        "--output",
        default="artifacts/identity/SPT-005/exports",
    )

    activate = subparsers.add_parser("activate")
    activate.add_argument("identity_id")
    activate.add_argument("--changed-by", required=True)
    activate.add_argument("--reason", required=True)
    activate.add_argument(
        "--repository",
        default="config/identity/SPT-005-identities.json",
    )
    activate.add_argument(
        "--history",
        default="artifacts/identity/SPT-005/identity-history.jsonl",
    )

    args = parser.parse_args()
    repository = IdentityRepository(args.repository)

    if args.command == "show":
        active = repository.active()
        print(
            json.dumps(
                asdict(active) if active else None,
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    if args.command == "export":
        active = repository.active()
        if active is None:
            raise SystemExit("No existe una identidad activa.")

        output = Path(args.output)
        export_flutter(active, output / "flutter-identity.json")
        export_web(active, output / "web-identity.json")
        export_api(active, output / "api-identity.json")

        print("SPT-005 exportado correctamente.")
        print(f"Identidad: {active.public_name}")
        print(f"Destino: {output}")
        return 0

    service = IdentityService(
        repository=repository,
        history_path=args.history,
    )
    active = service.activate(
        args.identity_id,
        changed_by=args.changed_by,
        reason=args.reason,
    )

    print("SPT-005 identidad activada.")
    print(f"Identidad: {active.public_name}")
    print(f"ID: {active.identity_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())