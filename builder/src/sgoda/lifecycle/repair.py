"""Diagnóstico y reparación segura de proyectos SGODA."""
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
import json, shutil
from datetime import UTC, datetime
from sgoda.core.constants import DEFAULT_DIRECTORIES
from sgoda.core.templates import build_project_files
@dataclass(frozen=True,slots=True)
class RepairAction:
    kind:str; path:str; status:str
@dataclass(frozen=True,slots=True)
class RepairReport:
    workspace:Path; dry_run:bool; actions:tuple[RepairAction,...]; backup_path:Path|None=None
    @property
    def changed(self):return any(a.status in {'planned','repaired'} for a in self.actions)
    @property
    def status(self):return 'PLANNED' if self.dry_run and self.changed else ('REPAIRED' if self.changed else 'HEALTHY')
    def to_dict(self):return {'workspace':str(self.workspace),'status':self.status,'dry_run':self.dry_run,'backup_path':str(self.backup_path) if self.backup_path else None,'actions':[{'kind':a.kind,'path':a.path,'status':a.status} for a in self.actions]}
    def to_text(self):
        lines = [
            "Reparación SGODA",
            f"Proyecto: {self.workspace}",
            f"Estado: {self.status}",
        ]
        if self.backup_path:
            lines.append(f"Respaldo: {self.backup_path}")
        for action in self.actions:
            lines.append(
                f"[{action.status.upper()}] {action.kind}: {action.path}"
            )
        return "\n".join(lines)

class ProjectRepairer:
    def __init__(self,workspace:str|Path):self.workspace=Path(workspace).expanduser().resolve()
    def _project_name(self):
        p=self.workspace/'sgoda.project.json'
        if p.is_file():
            try:return json.loads(p.read_text(encoding='utf-8-sig')).get('project',{}).get('name') or self.workspace.name
            except Exception:return self.workspace.name
        return self.workspace.name
    def repair(self,*,dry_run:bool=False,backup:bool=True)->RepairReport:
        actions=[]; backup_path=None
        templates=build_project_files(self._project_name())
        for rel in DEFAULT_DIRECTORIES:
            p=self.workspace/rel
            if not p.is_dir():
                actions.append(RepairAction('directory',rel,'planned' if dry_run else 'repaired'))
                if not dry_run:p.mkdir(parents=True,exist_ok=True)
        manifest=self.workspace/'sgoda.project.json'
        invalid=False
        if manifest.is_file():
            try:json.loads(manifest.read_text(encoding='utf-8-sig'))
            except Exception:invalid=True
        if invalid and backup and not dry_run:
            bd=self.workspace/'.sgoda'/'backups';bd.mkdir(parents=True,exist_ok=True)
            backup_path=bd/f'sgoda.project.repair.{datetime.now(UTC).strftime("%Y%m%dT%H%M%S%fZ")}.json';shutil.copy2(manifest,backup_path)
        for rel,content in templates.items():
            p=self.workspace/rel
            if not p.exists() or (rel=='sgoda.project.json' and invalid):
                actions.append(RepairAction('file',rel,'planned' if dry_run else 'repaired'))
                if not dry_run:
                    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(content,encoding='utf-8')
            else:actions.append(RepairAction('file',rel,'preserved'))
        return RepairReport(self.workspace,dry_run,tuple(actions),backup_path)
