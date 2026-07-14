"""Motor de migración de proyectos SGODA."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .backup import create_manifest_backup
from .migrations import (
    CURRENT_SCHEMA_VERSION,
    MIGRATIONS,
    SUPPORTED_SCHEMA_VERSIONS,
)
from .models import MigrationReport, MigrationStep


class MigrationError(RuntimeError):
    """Error controlado de migración."""


class ProjectMigrator:
    """Migra manifiestos SGODA de forma incremental y segura."""

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.manifest_path = self.workspace / "sgoda.project.json"

    def load_manifest(self) -> dict[str, Any]:
        if not self.manifest_path.is_file():
            raise MigrationError(
                f"No existe el manifiesto: {self.manifest_path}"
            )
        try:
            payload = json.loads(
                self.manifest_path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError) as exc:
            raise MigrationError(
                f"Manifiesto inválido: {exc}"
            ) from exc
        if not isinstance(payload, dict):
            raise MigrationError(
                "La raíz del manifiesto debe ser un objeto JSON."
            )
        return payload

    def plan(
        self,
        *,
        target_version: str = CURRENT_SCHEMA_VERSION,
    ) -> tuple[dict[str, Any], str, tuple[MigrationStep, ...]]:
        if target_version not in SUPPORTED_SCHEMA_VERSIONS:
            raise MigrationError(
                f"Versión destino no soportada: {target_version}"
            )

        original = self.load_manifest()
        source_version = str(original.get("schema_version", "1.0"))

        if source_version not in SUPPORTED_SCHEMA_VERSIONS:
            raise MigrationError(
                f"Versión origen no soportada: {source_version}"
            )

        if tuple(map(int, source_version.split("."))) > tuple(
            map(int, target_version.split("."))
        ):
            raise MigrationError(
                "No se permiten migraciones regresivas."
            )

        working = original
        current = source_version
        steps: list[MigrationStep] = []

        while current != target_version:
            migration = MIGRATIONS.get(current)
            if migration is None:
                raise MigrationError(
                    f"No existe ruta de migración desde {current}."
                )
            working, step = migration(working)
            steps.append(step)
            current = step.target

        return working, source_version, tuple(steps)

    def migrate(
        self,
        *,
        target_version: str = CURRENT_SCHEMA_VERSION,
        dry_run: bool = False,
        backup: bool = True,
    ) -> MigrationReport:
        migrated, source_version, steps = self.plan(
            target_version=target_version
        )
        changed = bool(steps)
        backup_path = None

        if changed and not dry_run:
            if backup:
                backup_path = create_manifest_backup(self.workspace)
            self.manifest_path.write_text(
                json.dumps(
                    migrated,
                    ensure_ascii=False,
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )

        return MigrationReport(
            workspace=self.workspace,
            source_version=source_version,
            target_version=target_version,
            changed=changed,
            dry_run=dry_run,
            backup_path=backup_path,
            steps=steps,
        )
