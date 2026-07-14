"""Respaldos seguros para migraciones SGODA."""

from datetime import UTC, datetime
from pathlib import Path
import shutil


def create_manifest_backup(workspace: Path) -> Path:
    """Copia el manifiesto a .sgoda/backups con marca temporal."""
    manifest = workspace / "sgoda.project.json"
    if not manifest.is_file():
        raise FileNotFoundError(f"No existe el manifiesto: {manifest}")

    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S%fZ")
    backup_dir = workspace / ".sgoda" / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup = backup_dir / f"sgoda.project.{timestamp}.json"
    shutil.copy2(manifest, backup)
    return backup
