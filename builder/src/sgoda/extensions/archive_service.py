"""Creación, lectura y verificación segura de paquetes .sgoda."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile
from typing import Any

from .package_manifest import PackageFile, PackageManifest


class ArchiveError(RuntimeError):
    """Paquete inválido o inseguro."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class ArchiveService:
    MANIFEST = "manifest.json"

    def build(self, staging: Path, destination: Path, manifest: PackageManifest) -> Path:
        staging.mkdir(parents=True, exist_ok=True)
        (staging / self.MANIFEST).write_text(
            json.dumps(manifest.to_dict(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        destination = destination.expanduser().resolve()
        if destination.suffix != ".sgoda":
            destination = destination.with_suffix(".sgoda")
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_suffix(".sgoda.tmp")
        if temporary.exists():
            temporary.unlink()
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(staging.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(staging).as_posix())
        temporary.replace(destination)
        return destination

    def read_manifest(self, package: Path) -> PackageManifest:
        package = package.expanduser().resolve()
        try:
            with zipfile.ZipFile(package) as archive:
                payload: Any = json.loads(archive.read(self.MANIFEST).decode("utf-8-sig"))
        except (OSError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as exc:
            raise ArchiveError(f"Paquete SGODA inválido: {exc}") from exc
        return PackageManifest(
            schema_version=str(payload["schema_version"]),
            builder_version=str(payload["builder_version"]),
            created_at=str(payload["created_at"]),
            source_workspace=str(payload.get("source_workspace", "")),
            files=tuple(PackageFile(**item) for item in payload.get("files", [])),
            statistics={str(k): int(v) for k, v in payload.get("statistics", {}).items()},
        )

    def verify(self, package: Path) -> dict[str, Any]:
        manifest = self.read_manifest(package)
        errors: list[str] = []
        try:
            with zipfile.ZipFile(package) as archive:
                names = set(archive.namelist())
                expected = {item.path for item in manifest.files}
                missing = sorted(expected - names)
                if missing:
                    errors.extend(f"Falta: {name}" for name in missing)
                for item in manifest.files:
                    if item.path not in names:
                        continue
                    data = archive.read(item.path)
                    checksum = hashlib.sha256(data).hexdigest()
                    if checksum != item.sha256:
                        errors.append(f"Checksum inválido: {item.path}")
                    if len(data) != item.size:
                        errors.append(f"Tamaño inválido: {item.path}")
        except (OSError, zipfile.BadZipFile) as exc:
            errors.append(str(exc))
        return {
            "valid": not errors,
            "package": str(Path(package).resolve()),
            "builder_version": manifest.builder_version,
            "files": len(manifest.files),
            "errors": errors,
        }

    def extract_verified(self, package: Path, destination: Path) -> Path:
        verification = self.verify(package)
        if not verification["valid"]:
            raise ArchiveError("; ".join(verification["errors"]))
        destination = destination.resolve()
        destination.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(package) as archive:
            for member in archive.infolist():
                target = (destination / member.filename).resolve()
                if destination not in target.parents and target != destination:
                    raise ArchiveError(f"Ruta insegura: {member.filename}")
                archive.extract(member, destination)
        return destination
