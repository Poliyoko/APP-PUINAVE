from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(root: Path, paths: Iterable[str]) -> dict:
    records = []

    for rel in sorted(set(paths)):
        path = root / rel
        if not path.is_file():
            continue

        records.append({
            "path": rel.replace("\\", "/"),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "records": records,
    }
