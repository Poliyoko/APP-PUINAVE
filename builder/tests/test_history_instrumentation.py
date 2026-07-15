import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.operations import HistoryStore


def event_types(workspace: Path) -> list[str]:
    return [
        event.event_type
        for event in HistoryStore(workspace).read_all()
    ]


def test_init_and_status_are_recorded(tmp_path, capsys) -> None:
    assert main([
        "init",
        str(tmp_path),
        "--project-name",
        "Instrumentación",
    ]) == 0
    capsys.readouterr()

    assert main(["status", str(tmp_path)]) == 0
    capsys.readouterr()

    assert event_types(tmp_path) == [
        "project_initialized",
        "status_collected",
    ]


def test_generate_is_recorded_but_dry_run_is_not(
    tmp_path,
    capsys,
) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Componentes"]) == 0
    capsys.readouterr()

    assert main(["generate", "backend", str(tmp_path)]) == 0
    capsys.readouterr()
    assert main([
        "generate",
        "frontend",
        str(tmp_path),
        "--dry-run",
    ]) == 0
    capsys.readouterr()

    events = HistoryStore(tmp_path).read_all()
    generated = [
        event
        for event in events
        if event.event_type == "component_generated"
    ]
    assert len(generated) == 1
    assert generated[0].details["component"] == "backend"


def test_audit_and_quality_are_recorded(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Calidad"]) == 0
    capsys.readouterr()

    assert main(["audit", str(tmp_path)]) == 0
    capsys.readouterr()
    assert main(["quality", str(tmp_path)]) == 0
    capsys.readouterr()

    types = event_types(tmp_path)
    assert "audit_executed" in types
    assert "quality_executed" in types


def test_migration_is_recorded_and_dry_run_is_not(
    tmp_path,
    capsys,
) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Migración"]) == 0
    capsys.readouterr()

    manifest_path = tmp_path / "sgoda.project.json"
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    payload["schema_version"] = "1.2"
    payload.pop("lifecycle", None)
    manifest_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    assert main([
        "migrate",
        str(tmp_path),
        "--to",
        "1.3",
        "--dry-run",
    ]) == 0
    capsys.readouterr()
    assert "project_migrated" not in event_types(tmp_path)

    assert main([
        "migrate",
        str(tmp_path),
        "--to",
        "1.3",
    ]) == 0
    capsys.readouterr()
    assert "project_migrated" in event_types(tmp_path)


def test_doctor_fix_is_recorded(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Reparación"]) == 0
    capsys.readouterr()

    (tmp_path / "README.md").unlink()
    assert main(["doctor", str(tmp_path), "--fix"]) == 0
    capsys.readouterr()

    assert "project_repaired" in event_types(tmp_path)
