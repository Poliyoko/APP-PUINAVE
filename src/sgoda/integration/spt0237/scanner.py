from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Iterable


class TransversalScanner:
    """Read-only scanner over the institutional repository."""

    COMPONENT_RE = re.compile(r"spt[-_]?023[._-]?([1-6])", re.IGNORECASE)

    def __init__(self, root: str | Path):
        self.root = Path(root)

    def files(self) -> list[Path]:
        excluded = {".git", ".venv", "venv", "__pycache__", ".pytest_cache"}
        return sorted(
            p for p in self.root.rglob("*")
            if p.is_file() and not any(part in excluded for part in p.parts)
        )

    @staticmethod
    def sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def component_files(self, component: str) -> list[Path]:
        number = component.rsplit(".", 1)[-1]
        patterns = (
            f"spt023{number}",
            f"spt-023.{number}",
            f"spt-023-{number}",
            f"spt_023_{number}",
        )
        result = []
        for path in self.files():
            normalized = str(path.relative_to(self.root)).lower().replace("\\", "/")
            if any(token in normalized for token in patterns):
                result.append(path)
        return result

    def inventory(self, scope: Iterable[str]) -> dict[str, list[Path]]:
        return {component: self.component_files(component) for component in scope}
