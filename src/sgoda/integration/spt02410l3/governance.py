from __future__ import annotations
import hashlib
import json
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def evidence_ledger(root: Path, paths: Iterable[str]) -> dict:
    declared = list(paths)
    records = []

    for rel in declared:
        path = root / rel
        if not path.is_file():
            records.append({
                "path": rel.replace("\\", "/"),
                "exists": False,
            })
            continue

        records.append({
            "path": rel.replace("\\", "/"),
            "exists": True,
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    return {
        "algorithm": "SHA-256",
        "declared_count": len(declared),
        "record_count": len(records),
        "missing_count": sum(1 for item in records if not item.get("exists")),
        "records": records,
    }


def load_json(root: Path, rel: str) -> dict:
    return json.loads((root / rel).read_text(encoding="utf-8"))
