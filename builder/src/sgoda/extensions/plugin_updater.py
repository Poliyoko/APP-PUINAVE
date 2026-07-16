"""Actualización atómica, respaldo y rollback de plugins."""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import UTC, datetime
from pathlib import Path
import shutil
import uuid

from .compatibility import parse_version
from .dependency_resolver import PluginDependencyResolver
from .integrity import create_integrity_snapshot
from .manager import ExtensionManagerError
from .models import ExtensionRecord
from .registry import ExtensionRegistry, ExtensionRegistryError
from .validator import ExtensionValidationError, load_manifest


@dataclass(frozen=True, slots=True)
class PluginUpdateResult:
    name: str
    previous_version: str
    version: str
    status: str
    installed_path: Path
    backup_path: Path | None
    rollback_performed: bool = False

    def to_dict(self) -> dict[str, str | bool | None]:
        return {
            "name": self.name,
            "previous_version": self.previous_version,
            "version": self.version,
            "status": self.status,
            "installed_path": str(self.installed_path),
            "backup_path": (
                str(self.backup_path)
                if self.backup_path is not None
                else None
            ),
            "rollback_performed": self.rollback_performed,
        }


class PluginUpdateError(ExtensionManagerError):
    """Actualización de plugin rechazada o fallida."""


class PluginUpdater:
    """Actualiza un plugin usando staging, respaldo y sustitución atómica."""

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.root = self.workspace / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(self.root)
        self.backup_root = self.root / "backups" / "plugins"

    @staticmethod
    def _copy_tree(source: Path, destination: Path) -> None:
        shutil.copytree(
            source,
            destination,
            ignore=shutil.ignore_patterns(
                "__pycache__",
                "*.pyc",
                ".git",
                ".pytest_cache",
            ),
        )

    def _validate_dependencies(
        self,
        candidate: ExtensionRecord,
    ) -> None:
        records = [
            candidate if record.name == candidate.name else record
            for record in self.registry.list("plugin")
        ]
        resolver = PluginDependencyResolver(records)
        issues = resolver.issues_for(candidate.name)
        cycles = resolver.detect_cycles()
        if issues:
            summary = ", ".join(
                f"{issue.dependency}:{issue.kind}"
                for issue in issues
            )
            raise PluginUpdateError(
                f"Dependencias inválidas para {candidate.name}: {summary}."
            )
        if cycles:
            raise PluginUpdateError(
                "La actualización introduce ciclos de dependencias."
            )

    def update(
        self,
        name: str,
        source: str | Path,
        *,
        backup: bool = True,
        allow_downgrade: bool = False,
    ) -> PluginUpdateResult:
        current = self.registry.get(f"plugin:{name}")
        if current is None:
            raise PluginUpdateError(f"No existe plugin:{name}.")

        source_path = Path(source).expanduser().resolve()
        try:
            manifest = load_manifest(source_path)
        except ExtensionValidationError as exc:
            raise PluginUpdateError(str(exc)) from exc

        if manifest.type != "plugin":
            raise PluginUpdateError(
                f"Se esperaba plugin, se recibió {manifest.type}."
            )
        if manifest.name != name:
            raise PluginUpdateError(
                f"El manifiesto corresponde a {manifest.name}, no a {name}."
            )

        current_version = parse_version(current.version)
        target_version = parse_version(manifest.version)
        if target_version == current_version:
            raise PluginUpdateError(
                f"{name} ya está en la versión {manifest.version}."
            )
        if target_version < current_version and not allow_downgrade:
            raise PluginUpdateError(
                "Downgrade bloqueado: use --allow-downgrade "
                "para autorizarlo explícitamente."
            )

        installed_path = Path(current.installed_path)
        source_dir = source_path if source_path.is_dir() else source_path.parent
        staging = installed_path.parent / (
            f".{installed_path.name}.staging-{uuid.uuid4().hex}"
        )
        displaced = installed_path.parent / (
            f".{installed_path.name}.previous-{uuid.uuid4().hex}"
        )
        backup_path: Path | None = None
        registry_replaced = False

        candidate = replace(
            current,
            version=manifest.version,
            description=manifest.description,
            builder_requires=manifest.builder_requires,
            dependencies=dict(manifest.dependencies),
            installed_path=str(installed_path),
            status="compatible" if current.enabled else "disabled",
        )
        self._validate_dependencies(candidate)

        try:
            self._copy_tree(source_dir, staging)
            snapshot = create_integrity_snapshot(staging)
            candidate = replace(
                candidate,
                checksum=snapshot.checksum,
                manifest_hash=snapshot.manifest_hash,
                file_hashes=snapshot.file_hashes,
                integrity_checked_at=datetime.now(UTC).isoformat(),
            )

            if backup:
                timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S%fZ")
                backup_path = self.backup_root / name / (
                    f"{current.version}-{timestamp}"
                )
                backup_path.parent.mkdir(parents=True, exist_ok=True)
                self._copy_tree(installed_path, backup_path)

            installed_path.replace(displaced)
            staging.replace(installed_path)

            try:
                self.registry.update_record(candidate)
                registry_replaced = True
            except ExtensionRegistryError as exc:
                raise PluginUpdateError(str(exc)) from exc

            shutil.rmtree(displaced, ignore_errors=True)
            return PluginUpdateResult(
                name=name,
                previous_version=current.version,
                version=manifest.version,
                status="UPDATED",
                installed_path=installed_path,
                backup_path=backup_path,
            )
        except Exception as exc:
            shutil.rmtree(staging, ignore_errors=True)

            if installed_path.exists() and displaced.exists():
                shutil.rmtree(installed_path, ignore_errors=True)
            if displaced.exists():
                displaced.replace(installed_path)

            if registry_replaced:
                try:
                    self.registry.update_record(current)
                except ExtensionRegistryError:
                    pass

            if isinstance(exc, PluginUpdateError):
                raise
            raise PluginUpdateError(
                f"Actualización fallida; rollback aplicado: {exc}"
            ) from exc
        finally:
            shutil.rmtree(staging, ignore_errors=True)
            shutil.rmtree(displaced, ignore_errors=True)
