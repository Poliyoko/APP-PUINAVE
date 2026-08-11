from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_manifest(root: Path, paths: Iterable[str]) -> dict:
    records = []
    for rel in sorted(set(paths)):
        p = root / rel
        if not p.is_file():
            continue
        records.append({
            "path": rel.replace("\\", "/"),
            "bytes": p.stat().st_size,
            "sha256": sha256(p),
        })
    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "records": records,
    }
