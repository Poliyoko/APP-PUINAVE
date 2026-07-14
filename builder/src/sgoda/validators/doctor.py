from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class CheckResult:
    name: str
    success: bool
    detail: str


def run_doctor(workspace: Path) -> list[CheckResult]:
    return [CheckResult("Directorio", workspace.is_dir(), str(workspace))]
