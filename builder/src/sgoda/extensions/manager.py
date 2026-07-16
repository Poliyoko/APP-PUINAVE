"""Gestores de instalación, listado y renderizado."""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import UTC, datetime
import json
from pathlib import Path
import shutil
from typing import Any

from sgoda import __version__

from .integrity import create_integrity_snapshot
from .models import ExtensionManifest, ExtensionRecord
from .registry import ExtensionRegistry, ExtensionRegistryError
from .validator import ExtensionValidationError, load_manifest


class ExtensionManagerError(RuntimeError):
    """Error controlado de administración de extensiones."""


@dataclass(frozen=True, slots=True)
class InstallResult:
    status: str
    manifest: ExtensionManifest
    installed_path: Path


@dataclass(frozen=True, slots=True)
class RenderResult:
    written_files: tuple[Path, ...]
    preserved_files: tuple[Path, ...]


class ExtensionManager:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.root = self.workspace / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(self.root)

    def _install_root(self, manifest: ExtensionManifest) -> Path:
        plural = "plugins" if manifest.type == "plugin" else "templates"
        return self.root / plural / manifest.name

    def install(
        self,
        source: str | Path,
        *,
        expected_type: str,
        force: bool = False,
    ) -> InstallResult:
        source_path = Path(source).expanduser().resolve()
        manifest = load_manifest(source_path)
        if manifest.type != expected_type:
            raise ExtensionManagerError(
                f"Se esperaba {expected_type}, se recibió {manifest.type}."
            )
        source_dir = source_path if source_path.is_dir() else source_path.parent
        destination = self._install_root(manifest)

        existing = self.registry.get(manifest.key)
        if existing and existing.version == manifest.version and not force:
            return InstallResult("ALREADY_INSTALLED", manifest, destination)
        if existing and not force:
            raise ExtensionManagerError(
                f"{manifest.key} ya existe con versión {existing.version}."
            )

        if destination.exists():
            if not force:
                raise ExtensionManagerError(
                    f"El destino ya existe: {destination}"
                )
            shutil.rmtree(destination)

        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(
            source_dir,
            destination,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache"
            ),
        )
        snapshot = create_integrity_snapshot(destination)
        record = replace(
            ExtensionRecord.create(manifest, destination),
            checksum=snapshot.checksum,
            manifest_hash=snapshot.manifest_hash,
            file_hashes=snapshot.file_hashes,
            integrity_checked_at=datetime.now(UTC).isoformat(),
        )
        try:
            registry_status = self.registry.register(record, force=force)
        except ExtensionRegistryError as exc:
            shutil.rmtree(destination, ignore_errors=True)
            raise ExtensionManagerError(str(exc)) from exc

        status = "UPDATED" if registry_status == "UPDATED" else "INSTALLED"
        return InstallResult(status, manifest, destination)

    def list(self, extension_type: str) -> list[ExtensionRecord]:
        return self.registry.list(extension_type)

    def info(self, extension_type: str, name: str) -> ExtensionRecord:
        record = self.registry.get(f"{extension_type}:{name}")
        if record is None:
            raise ExtensionManagerError(
                f"No existe {extension_type}:{name}."
            )
        return record

    def remove(self, extension_type: str, name: str) -> bool:
        key = f"{extension_type}:{name}"
        record = self.registry.get(key)
        if record is None:
            return False
        installed = Path(record.installed_path)
        if installed.exists():
            shutil.rmtree(installed)
        return self.registry.remove(key)

    def validate(
        self,
        source: str | Path,
        *,
        expected_type: str,
    ) -> ExtensionManifest:
        manifest = load_manifest(source)
        if manifest.type != expected_type:
            raise ExtensionValidationError(
                f"Se esperaba {expected_type}, se recibió {manifest.type}."
            )
        return manifest

    def render_template(
        self,
        name: str,
        destination: str | Path,
        *,
        variables: dict[str, str] | None = None,
        force: bool = False,
    ) -> RenderResult:
        record = self.info("template", name)
        installed = Path(record.installed_path)
        manifest = load_manifest(installed)
        destination_path = Path(destination).expanduser().resolve()
        values = {
            "project_name": destination_path.name,
            "component_name": name,
            "created_at": datetime.now(UTC).isoformat(),
            "builder_version": __version__,
        }
        values.update(variables or {})

        written: list[Path] = []
        preserved: list[Path] = []
        for relative in manifest.files:
            source = installed / relative
            target = destination_path / relative
            if target.exists() and not force:
                preserved.append(target)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            content = source.read_text(encoding="utf-8")
            for key, value in values.items():
                content = content.replace("{{ " + key + " }}", value)
                content = content.replace("{{" + key + "}}", value)
            target.write_text(content, encoding="utf-8")
            written.append(target)
        return RenderResult(tuple(written), tuple(preserved))


def record_to_dict(record: ExtensionRecord) -> dict[str, Any]:
    return record.to_dict()


def records_to_json(records: list[ExtensionRecord]) -> str:
    return json.dumps(
        [record.to_dict() for record in records],
        ensure_ascii=False,
        indent=2,
    )
