
from __future__ import annotations

import argparse
import json
from pathlib import Path

from .manager import InstitutionalRepositoryManager


def _write(path: str, payload: object) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument(
        "--operation",
        choices=("audit-master", "inventory", "validate", "report"),
        required=True,
    )
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    manager = InstitutionalRepositoryManager(args.root)

    if args.operation == "audit-master":
        payload = manager.audit_master_documents().to_dict()
        payload["approved"] = (
            payload["index_exists"]
            and payload["registry_exists"]
        )
        payload["exit_code"] = 0 if payload["approved"] else 2
    elif args.operation == "inventory":
        assets = [item.to_dict() for item in manager.inventory()]
        payload = {
            "approved": True,
            "exit_code": 0,
            "asset_count": len(assets),
            "assets": assets,
        }
    elif args.operation == "validate":
        payload = manager.validate_structure()
    else:
        payload = manager.build_report()

    _write(args.output_json, payload)
    print(json.dumps(payload, ensure_ascii=False))
    return int(payload.get("exit_code", 0))


if __name__ == "__main__":
    raise SystemExit(main())
