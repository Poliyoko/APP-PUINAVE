"""Validación del manifiesto."""

import json
from pathlib import Path


def validate_manifest(workspace: Path) -> tuple[bool, str]:
    path = workspace / "sgoda.project.json"

    if not path.is_file():
        return False, f"No existe: {path}"

    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return False, f"JSON inválido: {exc}"

    if manifest.get("project", {}).get("type") != "SGODA":
        return False, "El manifiesto no corresponde a un proyecto SGODA"

    return True, str(path)
