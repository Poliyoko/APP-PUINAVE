import shutil, sys
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True, slots=True)
class CheckResult:
    name: str
    success: bool
    detail: str

def run_doctor(workspace: Path) -> list[CheckResult]:
    pyproject = workspace/"pyproject.toml"
    if not pyproject.is_file():
        pyproject = workspace/"builder"/"pyproject.toml"
    return [
        CheckResult("Python", sys.version_info >= (3,11), sys.version.split()[0]),
        CheckResult("Directorio", workspace.is_dir(), str(workspace)),
        CheckResult("Git", shutil.which("git") is not None, shutil.which("git") or "No encontrado"),
        CheckResult("pyproject.toml", pyproject.is_file(), str(pyproject) if pyproject.is_file() else "No encontrado"),
    ]
