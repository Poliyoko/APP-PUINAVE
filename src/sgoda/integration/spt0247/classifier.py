from __future__ import annotations
from pathlib import Path
from typing import Iterable, List
from .models import SupplyChainSurface


class SupplyChainClassifier:
    def __init__(self, root: Path, tracked_paths: Iterable[str] | None = None):
        self.root = Path(root).resolve()
        self.tracked_paths = list(tracked_paths or [])

    def classify(self) -> List[SupplyChainSurface]:
        surfaces: List[SupplyChainSurface] = []
        for raw in self.tracked_paths:
            rel = raw.replace("\\", "/")
            low = rel.lower()

            if low.startswith(".github/workflows/") and low.endswith((".yml", ".yaml")):
                surfaces.append(SupplyChainSurface(rel, "CI_CD_WORKFLOW", {}))
                continue

            name = Path(low).name
            if (
                name.startswith("requirements") and name.endswith(".txt")
            ) or name in {
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
            }:
                surfaces.append(SupplyChainSurface(rel, "DEPENDENCY_MANIFEST", {}))
                continue

            if "/releases/" in f"/{low}" or low.startswith("releases/"):
                surfaces.append(SupplyChainSurface(rel, "RELEASE_ARTIFACT", {}))

        return surfaces
