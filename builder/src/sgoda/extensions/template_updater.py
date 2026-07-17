"""Actualización atómica, respaldos y rollback de plantillas SGODA."""
from __future__ import annotations
from dataclasses import dataclass, replace
from datetime import UTC, datetime
from pathlib import Path
import shutil
import uuid

from .compatibility import parse_version
from .integrity import create_integrity_snapshot
from .manager import ExtensionManagerError
from .registry import ExtensionRegistry, ExtensionRegistryError
from .template_validator import TemplateValidationError, TemplateValidator
from .validator import load_manifest

@dataclass(frozen=True, slots=True)
class TemplateUpdateResult:
    name: str
    previous_version: str
    version: str
    status: str
    installed_path: Path
    backup_path: Path | None
    rollback_performed: bool = False
    def to_dict(self):
        return {
            'name': self.name,
            'previous_version': self.previous_version,
            'version': self.version,
            'status': self.status,
            'installed_path': str(self.installed_path),
            'backup_path': str(self.backup_path) if self.backup_path else None,
            'rollback_performed': self.rollback_performed,
        }

class TemplateUpdateError(ExtensionManagerError):
    """Actualización de plantilla rechazada o fallida."""

class TemplateUpdater:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace=Path(workspace).expanduser().resolve()
        self.root=self.workspace/'.sgoda'/'extensions'
        self.registry=ExtensionRegistry(self.root)
        self.backup_root=self.root/'backups'/'templates'

    @staticmethod
    def _copy_tree(source: Path, destination: Path) -> None:
        shutil.copytree(source,destination,ignore=shutil.ignore_patterns('__pycache__','*.pyc','.git','.pytest_cache'))

    def update(self,name: str,source: str|Path,*,backup: bool=True,allow_downgrade: bool=False)->TemplateUpdateResult:
        current=self.registry.get(f'template:{name}')
        if current is None: raise TemplateUpdateError(f'No existe template:{name}.')
        source_path=Path(source).expanduser().resolve()
        try:
            metadata=TemplateValidator().validate(source_path)
            manifest=load_manifest(source_path)
        except (TemplateValidationError, OSError) as exc:
            raise TemplateUpdateError(str(exc)) from exc
        if metadata.name != name:
            raise TemplateUpdateError(f'El manifiesto corresponde a {metadata.name}, no a {name}.')
        current_v=parse_version(current.version); target_v=parse_version(metadata.version)
        if target_v == current_v: raise TemplateUpdateError(f'{name} ya está en la versión {metadata.version}.')
        if target_v < current_v and not allow_downgrade:
            raise TemplateUpdateError('Downgrade bloqueado: use --allow-downgrade para autorizarlo explícitamente.')
        installed=Path(current.installed_path)
        source_dir=source_path if source_path.is_dir() else source_path.parent
        staging=installed.parent/f'.{installed.name}.staging-{uuid.uuid4().hex}'
        displaced=installed.parent/f'.{installed.name}.previous-{uuid.uuid4().hex}'
        backup_path=None
        swapped=False
        try:
            self._copy_tree(source_dir,staging)
            snapshot=create_integrity_snapshot(staging)
            candidate=replace(current,version=manifest.version,description=manifest.description,
                builder_requires=manifest.builder_requires,dependencies=dict(manifest.dependencies),
                checksum=snapshot.checksum,manifest_hash=snapshot.manifest_hash,
                file_hashes=snapshot.file_hashes,integrity_checked_at=datetime.now(UTC).isoformat(),
                status='compatible' if current.enabled else 'disabled')
            if backup:
                stamp=datetime.now(UTC).strftime('%Y%m%dT%H%M%S%fZ')
                backup_path=self.backup_root/name/f'{current.version}-{stamp}'
                backup_path.parent.mkdir(parents=True,exist_ok=True)
                self._copy_tree(installed,backup_path)
            installed.replace(displaced); staging.replace(installed); swapped=True
            self.registry.update_record(candidate)
            shutil.rmtree(displaced,ignore_errors=True)
            return TemplateUpdateResult(name,current.version,metadata.version,'UPDATED',installed,backup_path)
        except Exception as exc:
            shutil.rmtree(staging,ignore_errors=True)
            if swapped and installed.exists(): shutil.rmtree(installed,ignore_errors=True)
            if displaced.exists(): displaced.replace(installed)
            try: self.registry.update_record(current)
            except Exception: pass
            if isinstance(exc,TemplateUpdateError): raise
            if isinstance(exc,ExtensionRegistryError):
                raise TemplateUpdateError(f'Actualización fallida; rollback aplicado: {exc}') from exc
            raise TemplateUpdateError(f'Actualización fallida; rollback aplicado: {exc}') from exc
        finally:
            shutil.rmtree(staging,ignore_errors=True); shutil.rmtree(displaced,ignore_errors=True)
