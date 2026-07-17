"""Persistencia JSON atómica del catálogo local."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .catalog_models import CatalogEntry, CatalogSnapshot


class CatalogStoreError(RuntimeError):
    """Error de lectura o escritura del catálogo."""


class CatalogStore:
    SCHEMA_VERSION = "1.0"

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.path = self.workspace / ".sgoda" / "extensions" / "catalog.json"

    def save(self, snapshot: CatalogSnapshot) -> Path:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".json.tmp")
        temporary.write_text(
            json.dumps(snapshot.to_dict(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        temporary.replace(self.path)
        return self.path

    def load(self) -> CatalogSnapshot:
        if not self.path.is_file():
            return CatalogSnapshot(
                schema_version=self.SCHEMA_VERSION,
                indexed_at="",
                entries=(),
            )
        try:
            payload: Any = json.loads(self.path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            raise CatalogStoreError(f"Catálogo inválido: {exc}") from exc
        if not isinstance(payload, dict):
            raise CatalogStoreError("La raíz del catálogo debe ser un objeto.")
        entries_raw = payload.get("entries", [])
        if not isinstance(entries_raw, list):
            raise CatalogStoreError("entries debe ser una lista.")
        entries = tuple(CatalogEntry(**entry) for entry in entries_raw)
        return CatalogSnapshot(
            schema_version=str(payload.get("schema_version", self.SCHEMA_VERSION)),
            indexed_at=str(payload.get("indexed_at", "")),
            entries=entries,
            duplicates=tuple(payload.get("duplicates", [])),
            errors=tuple(payload.get("errors", [])),
        )
