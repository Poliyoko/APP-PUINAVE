import subprocess
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True)
class AuditContext:
    root: Path

    @classmethod
    def create(cls,path):
        root=Path(path).resolve()
        if not root.is_dir(): raise ValueError(f"Repositorio inválido: {root}")
        return cls(root)

    def git(self,*args):
        try:
            p=subprocess.run(["git",*args],cwd=self.root,capture_output=True,text=True,encoding="utf-8",errors="replace")
        except OSError as exc:
            return False,str(exc)
        return p.returncode == 0,(p.stdout or p.stderr).strip()