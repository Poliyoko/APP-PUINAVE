from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


class RmrRegistry:
    """Registro Multimedia Reutilizable local, atÃ³mico y determinÃ­stico."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return {
                "schema_version": "1.0.0",
                "component": "ADR-010/RMR",
                "resources": {},
            }

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported RMR schema_version.")
        if not isinstance(data.get("resources"), dict):
            raise ValueError("RMR resources must be an object.")
        return data

    def upsert(self, record: dict[str, Any]) -> dict[str, Any]:
        resource_id = str(record.get("resource_id") or "").strip()
        if not resource_id:
            raise ValueError("RMR record requires resource_id.")

        data = self.load()
        resources = dict(data["resources"])
        resources[resource_id] = dict(record)
        data["resources"] = resources

        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_name(self.path.name + ".tmp")
        temp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(temp, self.path)
        return dict(resources[resource_id])

    def get(self, resource_id: str) -> dict[str, Any] | None:
        return self.load()["resources"].get(resource_id)
