"""Contexto verificable para SGD-114C."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class PolicyContext:
    root: Path
    increment: str
    policy: dict[str, Any]

    def exists(self, relative_path: str) -> bool:
        return (self.root / relative_path).exists()

    def is_file(self, relative_path: str) -> bool:
        return (self.root / relative_path).is_file()

    def is_dir(self, relative_path: str) -> bool:
        return (self.root / relative_path).is_dir()

    def read_json(self, relative_path: str) -> dict[str, Any]:
        path = self.root / relative_path
        return json.loads(path.read_text(encoding="utf-8-sig"))

    def git_status(self) -> list[str]:
        completed = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=self.root,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        return [
            line
            for line in completed.stdout.splitlines()
            if line.strip()
        ]

    def component_descriptors(self) -> list[Path]:
        return sorted(
            self.root.glob(
                f"config/**/*{self.increment}*component*.json"
            )
        )

    def releases(self) -> list[Path]:
        return sorted(
            (self.root / "releases").glob(
                f"{self.increment}-v*"
            )
        )

    def roadmap_validation(self) -> dict[str, Any] | None:
        path = (
            self.root
            / "artifacts"
            / "roadmap"
            / "SGD-116"
            / "validation.json"
        )
        if not path.is_file():
            return None
        return json.loads(path.read_text(encoding="utf-8-sig"))