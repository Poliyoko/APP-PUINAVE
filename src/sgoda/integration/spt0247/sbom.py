from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable, List


class InstitutionalSbom:
    @staticmethod
    def sha256(path: Path) -> str:
        h = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()

    @classmethod
    def build(cls, root: Path, tracked_paths: Iterable[str]) -> dict:
        components: List[dict] = []

        for rel in sorted(set(tracked_paths)):
            p = root / rel
            if not p.is_file():
                continue
            low = rel.lower()
            if (
                low.startswith(".github/workflows/")
                or low.endswith((
                    "requirements.txt",
                    "pyproject.toml",
                    "poetry.lock",
                    "pipfile",
                    "pipfile.lock",
                    "package.json",
                    "package-lock.json",
                    "yarn.lock",
                    "pnpm-lock.yaml",
                    "pubspec.yaml",
                    "pubspec.lock",
                ))
                or "/releases/" in f"/{low}"
            ):
                components.append({
                    "path": rel.replace("\\", "/"),
                    "sha256": cls.sha256(p),
                    "bytes": p.stat().st_size,
                })

        return {
            "format": "SGODA-INSTITUTIONAL-SBOM",
            "version": "1.0",
            "components": components,
            "component_count": len(components),
        }
