"""Registro de componentes en el manifiesto SGODA."""

import json
from datetime import UTC, datetime
from pathlib import Path


def register_component(
    workspace: Path,
    component: str,
    *,
    name: str | None = None,
    dry_run: bool = False,
) -> None:
    """Registra un componente generado en ``sgoda.project.json``."""
    path = workspace / "sgoda.project.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    components = manifest.setdefault("components", {})

    key = f"{component}:{name}" if name else component
    components[key] = {
        "type": component,
        "name": name,
        "status": "generated",
        "generated_at": datetime.now(UTC).isoformat(),
    }

    if not dry_run:
        path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
