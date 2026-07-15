"""Colector único del estado operativo de proyectos SGODA."""

from __future__ import annotations

from collections import Counter
from datetime import UTC, datetime
import json
from pathlib import Path
from typing import Any

from sgoda import __version__
from sgoda.audit import AuditEngine
from sgoda.extensions import ExtensionRegistry, ExtensionRegistryError

from .health import calculate_health
from .models import (
    AuditSnapshot,
    ExtensionSnapshot,
    LifecycleSnapshot,
    OperationStatus,
    ProjectSnapshot,
    ResourceSnapshot,
)


class OperationCollectionError(RuntimeError):
    """Error controlado durante la recolección del estado."""


class OperationCollector:
    """Construye una única instantánea operacional reutilizable."""

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.manifest_path = self.workspace / "sgoda.project.json"

    def _load_manifest(self) -> dict[str, Any]:
        if not self.workspace.is_dir():
            raise OperationCollectionError(
                f"El directorio del proyecto no existe: {self.workspace}"
            )
        if not self.manifest_path.is_file():
            raise OperationCollectionError(
                f"No existe el manifiesto: {self.manifest_path}"
            )
        try:
            payload = json.loads(
                self.manifest_path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError) as exc:
            raise OperationCollectionError(
                f"Manifiesto SGODA inválido: {exc}"
            ) from exc
        if not isinstance(payload, dict):
            raise OperationCollectionError(
                "La raíz del manifiesto debe ser un objeto JSON."
            )
        return payload

    @staticmethod
    def _component_counts(manifest: dict[str, Any]) -> dict[str, int]:
        raw = manifest.get("components", {})
        counter: Counter[str] = Counter()
        if isinstance(raw, dict):
            for key, value in raw.items():
                if isinstance(value, dict):
                    kind = str(value.get("type") or str(key).split(":", 1)[0])
                else:
                    kind = str(key).split(":", 1)[0]
                counter[kind] += 1
        return dict(sorted(counter.items()))

    def _extensions(self) -> ExtensionSnapshot:
        registry = ExtensionRegistry(
            self.workspace / ".sgoda" / "extensions"
        )
        try:
            records = registry.list()
        except ExtensionRegistryError:
            records = []
        return ExtensionSnapshot(
            plugins=sum(item.type == "plugin" for item in records),
            templates=sum(item.type == "template" for item in records),
            enabled=sum(item.enabled for item in records),
        )

    @staticmethod
    def _audit_categories(report) -> dict[str, dict[str, int]]:
        categories: dict[str, Counter[str]] = {}
        for finding in report.findings:
            counter = categories.setdefault(finding.category, Counter())
            counter[finding.severity.value] += 1
        return {
            category: dict(sorted(counts.items()))
            for category, counts in sorted(categories.items())
        }

    def collect(self) -> OperationStatus:
        manifest = self._load_manifest()
        project = manifest.get("project", {})
        if not isinstance(project, dict):
            project = {}
        lifecycle = manifest.get("lifecycle", {})
        if not isinstance(lifecycle, dict):
            lifecycle = {}
        history = lifecycle.get("migration_history", [])
        if not isinstance(history, list):
            history = []

        audit_report = AuditEngine().audit(self.workspace)
        audit = AuditSnapshot(
            status=audit_report.status,
            score=audit_report.score,
            errors=audit_report.errors,
            warnings=audit_report.warnings,
            information=audit_report.information,
            successes=audit_report.successes,
            categories=self._audit_categories(audit_report),
        )

        resources = ResourceSnapshot(
            lexicon=(self.workspace / "data/json/palabras.json").is_file(),
            metadata_catalog=(
                self.workspace / "data/metadata/catalog.json"
            ).is_file(),
            governance_documentation=(
                self.workspace / "docs/00_Gobierno/README.md"
            ).is_file(),
        )

        return OperationStatus(
            workspace=str(self.workspace),
            builder_version=__version__,
            collected_at=datetime.now(UTC).isoformat(),
            project=ProjectSnapshot(
                name=str(project.get("name", self.workspace.name)),
                version=str(project.get("version", "unknown")),
                type=str(project.get("type", "unknown")),
                status=str(project.get("status", "unknown")),
                schema_version=str(manifest.get("schema_version", "unknown")),
                created_at=(
                    str(project["created_at"])
                    if project.get("created_at") is not None else None
                ),
                updated_at=(
                    str(project["updated_at"])
                    if project.get("updated_at") is not None else None
                ),
            ),
            audit=audit,
            lifecycle=LifecycleSnapshot(
                migrations=len(history),
                last_migrated_at=(
                    str(lifecycle["last_migrated_at"])
                    if lifecycle.get("last_migrated_at") is not None else None
                ),
                last_repaired_at=(
                    str(lifecycle["last_repaired_at"])
                    if lifecycle.get("last_repaired_at") is not None else None
                ),
                managed_by=(
                    str(lifecycle["managed_by"])
                    if lifecycle.get("managed_by") is not None else None
                ),
            ),
            extensions=self._extensions(),
            resources=resources,
            components=self._component_counts(manifest),
            health=calculate_health(
                errors=audit.errors,
                warnings=audit.warnings,
            ),
        )
