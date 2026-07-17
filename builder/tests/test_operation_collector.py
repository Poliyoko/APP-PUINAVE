import json

from sgoda.cli.main import main
from sgoda.operations import OperationCollector


def test_collector_reads_project_and_extensions(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Observado"]) == 0
    registry = tmp_path / ".sgoda/extensions"
    registry.mkdir(parents=True)
    (registry / "registry.json").write_text(json.dumps({
        "schema_version": "1.0",
        "extensions": {
            "plugin:uno": {
                "type": "plugin", "name": "uno", "version": "1.0.0",
                "installed_path": str(registry / "plugins/uno"),
                "installed_at": "2026-07-14T00:00:00+00:00",
                "description": "", "enabled": True,
            },
            "template:dos": {
                "type": "template", "name": "dos", "version": "1.0.0",
                "installed_path": str(registry / "templates/dos"),
                "installed_at": "2026-07-14T00:00:00+00:00",
                "description": "", "enabled": True,
            },
        },
    }), encoding="utf-8")

    status = OperationCollector(tmp_path).collect()

    assert status.project.name == "Observado"
    assert status.project.schema_version == "1.3"
    assert status.builder_version == "1.13.0"
    assert status.extensions.plugins == 1
    assert status.extensions.templates == 1
    assert status.audit.score == 100
    assert status.health == "HEALTHY"
