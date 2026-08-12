from __future__ import annotations
from pathlib import PurePosixPath


def classify_surface(path: str) -> str:
    p = path.replace("\\", "/").lower()
    name = PurePosixPath(p).name

    if "/.github/workflows/" in "/" + p:
        return "CI_CD"
    if "/automation/" in "/" + p or "n8n" in p:
        return "AUTOMATION"
    if "docker" in name or "compose" in name or p.endswith(".containerfile"):
        return "CONTAINER"
    if p.endswith((".ps1", ".sh", ".bat", ".cmd")):
        return "SCRIPT"
    if p.endswith((".yaml", ".yml", ".json", ".toml", ".ini", ".cfg", ".conf", ".properties")):
        return "CONFIGURATION"
    if "fastapi" in p or "/api/" in "/" + p:
        return "API"
    if "postgres" in p or "database" in p or "/db/" in "/" + p:
        return "DATABASE"
    return "GENERAL"
