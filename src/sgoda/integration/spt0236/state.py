from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


class OrchestrationStateStore:
    """Persistencia local, atÃ³mica e idempotente del estado del orquestador."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return {
                "schema_version": "1.0.0",
                "component": "SPT-023.6",
                "runs": {},
            }

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported orchestration state schema_version.")
        if not isinstance(data.get("runs"), dict):
            raise ValueError("Orchestration runs must be an object.")
        return data

    def save_run(self, run: dict[str, Any]) -> dict[str, Any]:
        orchestration_id = str(run.get("orchestration_id") or "").strip()
        if not orchestration_id:
            raise ValueError("orchestration_id is required.")

        data = self.load()
        runs = dict(data["runs"])
        runs[orchestration_id] = dict(run)
        data["runs"] = runs

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        return dict(run)

    def get(self, orchestration_id: str) -> dict[str, Any] | None:
        return self.load()["runs"].get(orchestration_id)
