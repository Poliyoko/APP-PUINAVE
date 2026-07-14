"""Diagnóstico del entorno de ejecución del Builder."""

import shutil, sys
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True, slots=True)
class CheckResult:
    name: str
    success: bool
    detail: str

def run_doctor(workspace: Path) -> list[CheckResult]:
    candidates=(workspace/"pyproject.toml", workspace/"builder"/"pyproject.toml")
    found=next((p for p in candidates if p.is_file()), None)
    return [
        CheckResult("Python", sys.version_info >= (3,11), sys.version.split()[0]),
        CheckResult("Directorio", workspace.is_dir(), str(workspace)),
        CheckResult("Git", shutil.which("git") is not None, shutil.which("git") or "No encontrado"),
        CheckResult("pyproject.toml", found is not None, str(found) if found else "No encontrado"),
    ]
