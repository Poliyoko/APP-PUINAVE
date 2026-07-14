from dataclasses import dataclass
import sys,shutil
@dataclass(frozen=True,slots=True)
class CheckResult:
    name:str; success:bool; detail:str
def run_doctor(workspace): return [CheckResult("Python",sys.version_info>=(3,11),sys.version.split()[0]),CheckResult("Directorio",workspace.is_dir(),str(workspace)),CheckResult("Git",shutil.which("git") is not None,shutil.which("git") or "No encontrado")]
