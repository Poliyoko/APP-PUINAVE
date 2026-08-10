from __future__ import annotations

from pathlib import Path


class ProductionApiScope:
    """
    Strict production scope.

    Tests, documentation, releases, builder templates and security detector
    sources are excluded from the production API gate.
    """

    ALLOWED_ROOTS = (
        "src/sgoda/api",
        "src/sgoda/learning_platform",
        "src/sgoda/operational_platform",
        "src/sgoda/platform",
    )

    EXCLUDED_PARTS = (
        "__pycache__",
        "tests",
        "test",
        "fixtures",
        "fixture",
    )

    TEXT_SUFFIXES = {".py", ".json", ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf"}

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)

    def files(self) -> list[Path]:
        result: list[Path] = []
        for rel_root in self.ALLOWED_ROOTS:
            base = self.root / Path(rel_root)
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file():
                    continue
                if path.suffix.lower() not in self.TEXT_SUFFIXES:
                    continue
                if any(part.lower() in self.EXCLUDED_PARTS for part in path.parts):
                    continue
                result.append(path)
        return sorted(set(result))
