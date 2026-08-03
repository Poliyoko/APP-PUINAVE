
from __future__ import annotations

import argparse
import json
from pathlib import Path

from .service import InstitutionalReleaseManager


def _write(path: str, payload: object) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument(
        "--operation",
        choices=(
            "discover",
            "migrate-manifests",
            "normalize-all",
            "validate",
            "close",
        ),
        required=True,
    )
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    manager = InstitutionalReleaseManager(args.root)

    if args.operation == "discover":
        payload = {
            "approved": True,
            "exit_code": 0,
            "duplicates": [
                {"source": source, "canonical": canonical}
                for source, canonical in manager.discover_duplicates()
            ],
        }

    elif args.operation == "migrate-manifests":
        migrated = manager.migrate_missing_manifests()
        payload = {
            "approved": True,
            "exit_code": 0,
            "migrated": list(migrated),
            "migrated_count": len(migrated),
        }

    elif args.operation == "normalize-all":
        results = [
            result.to_dict()
            for result in manager.normalize_all()
        ]
        approved = all(item["approved"] for item in results)
        payload = {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "results": results,
        }

    elif args.operation == "close":
        migrated = manager.migrate_missing_manifests()
        normalized = [
            result.to_dict()
            for result in manager.normalize_all()
        ]
        validation = manager.validate()
        approved = (
            all(item["approved"] for item in normalized)
            and validation["approved"]
        )
        payload = {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "migrated": list(migrated),
            "migrated_count": len(migrated),
            "normalized": normalized,
            "validation": validation,
        }

    else:
        payload = manager.validate()

    _write(args.output_json, payload)
    print(json.dumps(payload, ensure_ascii=False))
    return int(payload["exit_code"])


if __name__ == "__main__":
    raise SystemExit(main())
