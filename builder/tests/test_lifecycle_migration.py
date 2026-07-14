import json

from sgoda.lifecycle import ProjectMigrator
from sgoda.cli.main import main


def write_old_manifest(tmp_path, version: str) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Migración"]) == 0
    path = tmp_path / "sgoda.project.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["schema_version"] = version
    payload.pop("lifecycle", None)
    if version == "1.0":
        payload.pop("components", None)
        payload.pop("governance", None)
        payload.pop("resources", None)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def test_migrate_1_0_to_current(tmp_path) -> None:
    write_old_manifest(tmp_path, "1.0")

    report = ProjectMigrator(tmp_path).migrate()

    assert report.changed is True
    assert report.source_version == "1.0"
    assert report.target_version == "1.3"
    assert len(report.steps) == 3
    assert report.backup_path is not None
    payload = json.loads(
        (tmp_path / "sgoda.project.json").read_text(encoding="utf-8")
    )
    assert payload["schema_version"] == "1.3"
    assert payload["governance"]["data_owner"]
    assert payload["lifecycle"]["migration_history"]


def test_dry_run_does_not_modify_or_backup(tmp_path) -> None:
    write_old_manifest(tmp_path, "1.1")
    path = tmp_path / "sgoda.project.json"
    original = path.read_text(encoding="utf-8")

    report = ProjectMigrator(tmp_path).migrate(dry_run=True)

    assert report.status == "PLANNED"
    assert report.backup_path is None
    assert path.read_text(encoding="utf-8") == original
    assert not (tmp_path / ".sgoda/backups").exists()


def test_current_project_is_unchanged(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Actual"]) == 0

    report = ProjectMigrator(tmp_path).migrate()

    assert report.changed is False
    assert report.status == "UP_TO_DATE"
    assert report.steps == ()
