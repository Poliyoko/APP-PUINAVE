"""Reporte consolidado del ecosistema de extensiones."""

from __future__ import annotations

from datetime import UTC, datetime
import html
import json
from pathlib import Path
from typing import Any

from sgoda import __version__
from sgoda.operations import HistoryStore

from .bundle_store import BundleStore
from .catalog_service import CatalogService


class ConsolidatedReportService:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()

    def collect(self, *, history_limit: int = 20) -> dict[str, Any]:
        catalog = CatalogService(self.workspace).rebuild()
        bundles = BundleStore(self.workspace).list()
        try:
            history = HistoryStore(self.workspace).query(limit=history_limit)
            history_payload = [event.to_dict() for event in history]
        except Exception:
            history_payload = []
        return {
            "report": "SGODA consolidated ecosystem",
            "generated_at": datetime.now(UTC).isoformat(),
            "builder_version": __version__,
            "workspace": str(self.workspace),
            "statistics": {
                **catalog.statistics(),
                "bundles": len(bundles),
                "history_events": len(history_payload),
            },
            "extensions": [entry.to_dict() for entry in catalog.entries],
            "bundles": [bundle.to_dict() for bundle in bundles],
            "history": history_payload,
            "catalog_errors": list(catalog.errors),
            "catalog_duplicates": list(catalog.duplicates),
        }

    def render(self, payload: dict[str, Any], output_format: str) -> str:
        if output_format == "json":
            return json.dumps(payload, ensure_ascii=False, indent=2)
        if output_format == "markdown":
            return self._markdown(payload)
        if output_format == "html":
            body = html.escape(self._markdown(payload))
            return (
                "<!doctype html><html><head><meta charset='utf-8'>"
                "<title>SGODA Consolidated Report</title></head><body>"
                f"<pre>{body}</pre></body></html>"
            )
        if output_format == "text":
            s = payload["statistics"]
            return "\n".join([
                "SGODA — Reporte consolidado",
                f"Builder: {payload['builder_version']}",
                f"Workspace: {payload['workspace']}",
                f"Extensiones: {s['total']} (plugins={s['plugins']}, templates={s['templates']})",
                f"Bundles: {s['bundles']}",
                f"Habilitadas: {s['enabled']} | Deshabilitadas: {s['disabled']}",
                f"Errores de catálogo: {s['errors']} | Duplicados: {s['duplicates']}",
            ])
        raise ValueError(f"Formato no soportado: {output_format}")

    def save(
        self,
        destination: str | Path,
        *,
        output_format: str = "markdown",
        history_limit: int = 20,
    ) -> Path:
        path = Path(destination).expanduser().resolve()
        suffix = {"json": ".json", "markdown": ".md", "html": ".html", "text": ".txt"}[output_format]
        if path.suffix.lower() != suffix:
            path = path.with_suffix(suffix)
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = self.collect(history_limit=history_limit)
        path.write_text(self.render(payload, output_format) + "\n", encoding="utf-8")
        return path

    def _markdown(self, payload: dict[str, Any]) -> str:
        s = payload["statistics"]
        lines = [
            "# Reporte consolidado SGODA",
            "",
            f"- Builder: `{payload['builder_version']}`",
            f"- Workspace: `{payload['workspace']}`",
            f"- Generado: `{payload['generated_at']}`",
            "",
            "## Resumen",
            "",
            f"- Extensiones: **{s['total']}**",
            f"- Plugins: **{s['plugins']}**",
            f"- Plantillas: **{s['templates']}**",
            f"- Bundles: **{s['bundles']}**",
            f"- Habilitadas: **{s['enabled']}**",
            f"- Deshabilitadas: **{s['disabled']}**",
            "",
            "## Extensiones",
            "",
            "| Tipo | Nombre | Versión | Estado | Habilitada |",
            "|---|---|---:|---|---|",
        ]
        for item in payload["extensions"]:
            lines.append(
                f"| {item['type']} | {item['name']} | {item['version']} | "
                f"{item['status']} | {'sí' if item['enabled'] else 'no'} |"
            )
        lines.extend(["", "## Bundles", ""])
        for bundle in payload["bundles"]:
            lines.append(f"- **{bundle['name']}**: {len(bundle['items'])} extensiones")
        if not payload["bundles"]:
            lines.append("- Sin bundles.")
        return "\n".join(lines)
