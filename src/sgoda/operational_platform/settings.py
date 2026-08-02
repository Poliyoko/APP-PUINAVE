"""Configuración local de SPT-011."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class OperationalSettings:
    database_url: str
    database_mode: str
    api_host: str
    api_port: int
    n8n_enabled: bool
    n8n_base_url: str
    flutter_contract_enabled: bool
    require_validated_entries: bool
    no_invention: bool

    @classmethod
    def from_json(
        cls,
        path: str | Path,
    ) -> "OperationalSettings":
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )

        return cls(
            database_url=str(
                payload.get(
                    "database_url",
                    "sqlite:///artifacts/operational_platform/sgoda.db",
                )
            ),
            database_mode=str(
                payload.get("database_mode", "local")
            ),
            api_host=str(payload.get("api_host", "127.0.0.1")),
            api_port=int(payload.get("api_port", 8000)),
            n8n_enabled=bool(payload.get("n8n_enabled", False)),
            n8n_base_url=str(
                payload.get(
                    "n8n_base_url",
                    "http://127.0.0.1:5678",
                )
            ),
            flutter_contract_enabled=bool(
                payload.get("flutter_contract_enabled", True)
            ),
            require_validated_entries=bool(
                payload.get("require_validated_entries", True)
            ),
            no_invention=bool(payload.get("no_invention", True)),
        )