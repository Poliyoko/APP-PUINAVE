"""Servicio de alto nivel para bundles."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import shutil

from .bundle_executor import BundleExecutor
from .bundle_models import BundleExecutionResult, BundleItem, ExtensionBundle
from .bundle_store import BundleStore, BundleStoreError
from .catalog_service import CatalogService


class BundleServiceError(RuntimeError):
    """Operación inválida de bundle."""


class BundleService:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.store = BundleStore(self.workspace)
        self.catalog = CatalogService(self.workspace)
        self.executor = BundleExecutor(self.workspace)

    def create(
        self,
        name: str,
        selectors: list[str] | tuple[str, ...] = (),
        *,
        include_all: bool = False,
        description: str = "",
        force: bool = False,
    ) -> ExtensionBundle:
        normalized = self.store.validate_name(name)
        path = self.store.path_for(normalized)
        if path.exists() and not force:
            raise BundleServiceError(f"El bundle ya existe: {normalized}.")

        entries = self.catalog.snapshot().entries
        selected = []
        selector_set = set(selectors)
        if include_all:
            selected = list(entries)
        else:
            for selector in selector_set:
                if ":" not in selector:
                    raise BundleServiceError(
                        f"Selector inválido: {selector}; use tipo:nombre."
                    )
                matches = [entry for entry in entries if entry.key == selector]
                if not matches:
                    raise BundleServiceError(
                        f"No existe en el catálogo: {selector}."
                    )
                selected.append(matches[0])
        if not selected:
            raise BundleServiceError("El bundle debe contener al menos una extensión.")

        asset_root = self.store.assets_root / normalized
        if asset_root.exists() and force:
            shutil.rmtree(asset_root)
        items: list[BundleItem] = []
        for entry in sorted(selected, key=lambda value: (value.type, value.name)):
            source = Path(entry.location)
            if not source.is_dir():
                raise BundleServiceError(f"Ruta inexistente para {entry.key}: {source}")
            asset = asset_root / entry.type / entry.name
            asset.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(
                source,
                asset,
                dirs_exist_ok=True,
                ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".pytest_cache"),
            )
            items.append(
                BundleItem(
                    type=entry.type,
                    name=entry.name,
                    version=entry.version,
                    source=str(asset),
                    enabled=entry.enabled,
                )
            )

        now = datetime.now(UTC).isoformat()
        created_at = now
        if path.exists():
            created_at = self.store.load(normalized).created_at
        bundle = ExtensionBundle(
            schema_version=BundleStore.SCHEMA_VERSION,
            name=normalized,
            description=description,
            created_at=created_at,
            updated_at=now,
            items=tuple(items),
        )
        self.store.save(bundle)
        return bundle

    def list(self) -> list[ExtensionBundle]:
        return self.store.list()

    def info(self, name: str) -> ExtensionBundle:
        try:
            return self.store.load(name)
        except BundleStoreError as exc:
            raise BundleServiceError(str(exc)) from exc

    def execute(
        self,
        name: str,
        action: str,
        *,
        dry_run: bool = False,
    ) -> BundleExecutionResult:
        bundle = self.info(name)
        result = self.executor.execute(bundle, action, dry_run=dry_run)
        self.catalog.rebuild()
        return result
