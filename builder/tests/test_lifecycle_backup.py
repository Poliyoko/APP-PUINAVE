from pathlib import Path

from sgoda.lifecycle.backup import create_manifest_backup
from sgoda.cli.main import main


def test_backup_copies_manifest(tmp_path: Path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Backup"]) == 0
    original = (tmp_path / "sgoda.project.json").read_text(encoding="utf-8")

    backup = create_manifest_backup(tmp_path)

    assert backup.is_file()
    assert backup.parent == tmp_path / ".sgoda" / "backups"
    assert backup.read_text(encoding="utf-8") == original
