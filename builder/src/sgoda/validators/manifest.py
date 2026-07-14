import json
from pathlib import Path


def validate_manifest(workspace: Path) -> tuple[bool, str]:
    path = workspace / "sgoda.project.json"
    if not path.is_file():
        return False, f"No existe: {path}"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("project", {}).get("type") != "SGODA":
        return False, "Proyecto inválido"
    return True, str(path)
