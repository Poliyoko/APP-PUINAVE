"""Diagnóstico del entorno."""

import shutil
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class CheckResult:
    name: str
    success: bool
    detail: str


def run_doctor(workspace: Path) -> list[CheckResult]:
    return [
        CheckResult("Python", sys.version_info >= (3, 11), sys.version.split()[0]),
        CheckResult("Directorio", workspace.is_dir(), str(workspace)),
        CheckResult(
            "Git",
            shutil.which("git") is not None,
            shutil.which("git") or "No encontrado",
        ),
    ]
