"""Ejecución transaccional de operaciones sobre bundles."""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path
import shutil
import tempfile

from .bundle_models import BundleExecutionResult, BundleOperation, ExtensionBundle
from .bundle_planner import BundlePlanner
from .manager import ExtensionManager
from .plugin_state import PluginStateService
from .template_state import TemplateStateService


class BundleExecutionError(RuntimeError):
    """La operación masiva falló y fue revertida."""


class BundleExecutor:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.extensions_root = self.workspace / ".sgoda" / "extensions"
        self.manager = ExtensionManager(self.workspace)
        self.planner = BundlePlanner(self.workspace)

    def execute(
        self,
        bundle: ExtensionBundle,
        action: str,
        *,
        dry_run: bool = False,
    ) -> BundleExecutionResult:
        plan = self.planner.plan(bundle, action)
        if dry_run:
            return BundleExecutionResult(bundle.name, action, "PLANNED", plan)

        backup_parent = Path(tempfile.mkdtemp(prefix="sgoda-bundle-"))
        backup = backup_parent / "extensions"
        existed = self.extensions_root.exists()
        if existed:
            shutil.copytree(self.extensions_root, backup)

        completed: list[BundleOperation] = []
        try:
            for operation in plan:
                if operation.status == "skipped":
                    completed.append(operation)
                    continue
                self._apply(operation)
                completed.append(replace(operation, status="completed"))
        except Exception as exc:
            if self.extensions_root.exists():
                shutil.rmtree(self.extensions_root)
            if existed:
                shutil.copytree(backup, self.extensions_root)
            failed = replace(operation, status="failed", message=str(exc))
            completed.append(failed)
            shutil.rmtree(backup_parent, ignore_errors=True)
            return BundleExecutionResult(
                bundle.name,
                action,
                "ROLLED_BACK",
                tuple(completed),
                rolled_back=True,
            )

        shutil.rmtree(backup_parent, ignore_errors=True)
        return BundleExecutionResult(
            bundle.name,
            action,
            "COMPLETED",
            tuple(completed),
        )

    def _apply(self, operation: BundleOperation) -> None:
        item = operation.item
        if operation.action in {"install", "update"}:
            source = Path(item.source)
            if not source.is_dir():
                raise BundleExecutionError(f"Fuente inexistente: {source}")
            self.manager.install(
                source,
                expected_type=item.type,
                force=operation.action == "update",
            )
            return
        if operation.action == "uninstall":
            self.manager.remove(item.type, item.name)
            return
        enabled = operation.action == "enable"
        if item.type == "plugin":
            PluginStateService(self.workspace).set_enabled(item.name, enabled)
        else:
            TemplateStateService(self.workspace).set_enabled(item.name, enabled)
