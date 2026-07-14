import json

from sgoda.cli.main import main


def downgrade_manifest(tmp_path, version: str = "1.2") -> None:
    assert main(["init", str(tmp_path), "--project-name", "CLI"]) == 0
    path = tmp_path / "sgoda.project.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["schema_version"] = version
    payload.pop("lifecycle", None)
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_upgrade_cli(tmp_path, capsys) -> None:
    downgrade_manifest(tmp_path)

    assert main(["upgrade", str(tmp_path)]) == 0
    output = capsys.readouterr().out

    assert "Estado: MIGRATED" in output
    assert "1.2 -> 1.3" in output


def test_upgrade_cli_json_dry_run(tmp_path, capsys) -> None:
    downgrade_manifest(tmp_path, "1.1")
    capsys.readouterr()

    assert (
        main(
            [
                "upgrade",
                str(tmp_path),
                "--dry-run",
                "--format",
                "json",
            ]
        )
        == 0
    )
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "PLANNED"
    assert payload["target_version"] == "1.3"


def test_migrate_rejects_downgrade(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "No downgrade"]) == 0
    capsys.readouterr()

    assert main(["migrate", str(tmp_path), "--to", "1.2"]) == 1
    assert "regresivas" in capsys.readouterr().out
