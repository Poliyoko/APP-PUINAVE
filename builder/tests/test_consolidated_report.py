import json
from pathlib import Path

from sgoda.extensions import ConsolidatedReportService, ExtensionManager


def make_plugin(root: Path) -> Path:
    source = root / "reportable"
    source.mkdir()
    (source / "plugin.py").write_text("def register(): return None\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(json.dumps({
        "schema_version": "1.0", "type": "plugin", "name": "reportable",
        "version": "1.0.0", "builder_requires": ">=1.12.0,<2.0.0",
        "entry_point": "plugin:register", "dependencies": {},
    }), encoding="utf-8")
    return source


def test_report_formats_and_save(tmp_path) -> None:
    workspace = tmp_path / "workspace"
    ExtensionManager(workspace).install(make_plugin(tmp_path), expected_type="plugin")
    service = ConsolidatedReportService(workspace)
    payload = service.collect()
    assert payload["statistics"]["plugins"] == 1
    assert "Reporte consolidado SGODA" in service.render(payload, "markdown")
    assert json.loads(service.render(payload, "json"))["statistics"]["total"] == 1
    saved = service.save(tmp_path / "report", output_format="html")
    assert saved.suffix == ".html"
    assert saved.is_file()
