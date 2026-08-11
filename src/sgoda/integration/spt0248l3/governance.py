from __future__ import annotations
import hashlib
import json
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def evidence_ledger(root: Path, paths: Iterable[str]) -> dict:
    records = []

    for rel in list(paths):
        p = root / rel
        if not p.is_file():
            records.append({
                "path": rel.replace("\\", "/"),
                "exists": False,
            })
            continue

        records.append({
            "path": rel.replace("\\", "/"),
            "exists": True,
            "bytes": p.stat().st_size,
            "sha256": sha256(p),
        })

    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "missing_count": len([r for r in records if not r.get("exists")]),
        "records": records,
    }


def load_json(root: Path, rel: str):
    return json.loads((root / rel).read_text(encoding="utf-8"))
