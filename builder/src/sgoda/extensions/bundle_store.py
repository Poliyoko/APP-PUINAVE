"""Persistencia atómica de bundles."""

from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any

from .bundle_models import BundleItem, ExtensionBundle


class BundleStoreError(RuntimeError):
    """Error de persistencia de bundles."""


class BundleStore:
    SCHEMA_VERSION = "1.0"
    _NAME = re.compile(r"^[a-z0-9][a-z0-9._-]{1,63}$")

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.root = self.workspace / ".sgoda" / "extensions" / "bundles"
        self.assets_root = self.root / "assets"

    def validate_name(self, name: str) -> str:
        normalized = name.strip().lower()
        if not self._NAME.fullmatch(normalized):
            raise BundleStoreError(
                "Nombre de bundle inválido; use minúsculas, números, '.', '_' o '-'."
            )
        return normalized

    def path_for(self, name: str) -> Path:
        return self.root / f"{self.validate_name(name)}.bundle.json"

    def save(self, bundle: ExtensionBundle) -> Path:
        path = self.path_for(bundle.name)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(bundle.to_dict(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        temporary.replace(path)
        return path

    def load(self, name: str) -> ExtensionBundle:
        path = self.path_for(name)
        if not path.is_file():
            raise BundleStoreError(f"No existe el bundle: {name}.")
        try:
            payload: Any = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            raise BundleStoreError(f"Bundle inválido: {exc}") from exc
        if not isinstance(payload, dict):
            raise BundleStoreError("La raíz del bundle debe ser un objeto.")
        items_raw = payload.get("items", [])
        if not isinstance(items_raw, list):
            raise BundleStoreError("items debe ser una lista.")
        return ExtensionBundle(
            schema_version=str(payload.get("schema_version", self.SCHEMA_VERSION)),
            name=str(payload["name"]),
            description=str(payload.get("description", "")),
            created_at=str(payload.get("created_at", "")),
            updated_at=str(payload.get("updated_at", "")),
            items=tuple(BundleItem(**item) for item in items_raw),
        )

    def list(self) -> list[ExtensionBundle]:
        if not self.root.is_dir():
            return []
        bundles: list[ExtensionBundle] = []
        for path in sorted(self.root.glob("*.bundle.json")):
            bundles.append(self.load(path.name.removesuffix(".bundle.json")))
        return bundles
