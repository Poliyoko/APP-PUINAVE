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


def build_sbom(root: Path, paths: Iterable[str]) -> dict:
    components = []
    for rel in sorted(set(paths)):
        p = root / rel
        if not p.is_file():
            continue
        components.append({
            "type": "file",
            "path": rel.replace("\\", "/"),
            "sha256": sha256(p),
            "bytes": p.stat().st_size,
        })

    return {
        "format": "SGODA-SBOM",
        "version": "2.0",
        "component_count": len(components),
        "components": components,
    }
