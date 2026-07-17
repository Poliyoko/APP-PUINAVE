"""Consulta de respaldos/versiones disponibles de plantillas."""
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True, slots=True)
class TemplateBackup:
    name: str
    version: str
    path: Path
    def to_dict(self): return {'name':self.name,'version':self.version,'path':str(self.path)}

class TemplateVersionService:
    def __init__(self,workspace: str|Path)->None:
        self.root=Path(workspace).expanduser().resolve()/'.sgoda'/'extensions'/'backups'/'templates'
    def list_backups(self,name: str)->list[TemplateBackup]:
        root=self.root/name
        if not root.is_dir(): return []
        result=[]
        for path in sorted(root.iterdir(),reverse=True):
            if path.is_dir(): result.append(TemplateBackup(name,path.name.split('-',1)[0],path))
        return result
