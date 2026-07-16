"""Registro persistente de extensiones SGODA."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import ExtensionRecord


class ExtensionRegistryError(RuntimeError):
    """Error de persistencia o conflicto del registro."""


class ExtensionRegistry:
    """Registro JSON idempotente para plugins y plantillas."""

    SCHEMA_VERSION = "1.0"

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).expanduser().resolve()
        self.registry_path = self.root / "registry.json"

    def _empty(self) -> dict[str, Any]:
        return {
            "schema_version": self.SCHEMA_VERSION,
            "extensions": {},
        }

    def load(self) -> dict[str, Any]:
        if not self.registry_path.is_file():
            return self._empty()
        try:
            payload = json.loads(
                self.registry_path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError) as exc:
            raise ExtensionRegistryError(
                f"Registro inválido: {exc}"
            ) from exc
        if not isinstance(payload, dict):
            raise ExtensionRegistryError(
                "La raíz del registro debe ser un objeto JSON."
            )
        payload.setdefault("schema_version", self.SCHEMA_VERSION)
        payload.setdefault("extensions", {})
        if not isinstance(payload["extensions"], dict):
            raise ExtensionRegistryError(
                "extensions debe ser un objeto JSON."
            )
        return payload

    def save(self, payload: dict[str, Any]) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        temporary = self.registry_path.with_suffix(".json.tmp")
        temporary.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        temporary.replace(self.registry_path)

    def list(self, extension_type: str | None = None) -> list[ExtensionRecord]:
        entries = self.load()["extensions"]
        records = [
            ExtensionRecord(**entry)
            for entry in entries.values()
            if extension_type is None or entry.get("type") == extension_type
        ]
        return sorted(records, key=lambda item: (item.type, item.name))

    def get(self, key: str) -> ExtensionRecord | None:
        entry = self.load()["extensions"].get(key)
        return ExtensionRecord(**entry) if entry else None

    def register(
        self,
        record: ExtensionRecord,
        *,
        force: bool = False,
    ) -> str:
        payload = self.load()
        entries = payload["extensions"]
        existing = entries.get(record.key)

        if existing:
            if existing.get("version") == record.version and not force:
                return "ALREADY_REGISTERED"
            if not force:
                raise ExtensionRegistryError(
                    f"Conflicto: {record.key} ya está registrado."
                )
            status = "UPDATED"
        else:
            status = "REGISTERED"

        entries[record.key] = record.to_dict()
        self.save(payload)
        return status


    def update_record(self, record: ExtensionRecord) -> None:
        payload = self.load()
        entries = payload["extensions"]
        if record.key not in entries:
            raise ExtensionRegistryError(
                f"No existe el registro {record.key}."
            )
        entries[record.key] = record.to_dict()
        self.save(payload)

    def remove(self, key: str) -> bool:
        payload = self.load()
        entries = payload["extensions"]
        if key not in entries:
            return False
        del entries[key]
        self.save(payload)
        return True
