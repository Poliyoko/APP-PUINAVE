import json

from sgoda.cli.main import main
from sgoda.operations import (
    ExecutiveReportBuilder,
    report_to_json,
    report_to_markdown,
)


def test_markdown_report_has_executive_sections(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Markdown"]) == 0
    report = ExecutiveReportBuilder(tmp_path).build()

    content = report_to_markdown(report)

    assert "# Reporte Ejecutivo SGODA" in content
    assert "## Resumen Ejecutivo" in content
    assert "## Auditoría y Calidad" in content
    assert "## Historial Reciente" in content
    assert "## Recomendaciones" in content


def test_json_report_is_valid(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Puinave"]) == 0
    payload = json.loads(
        report_to_json(ExecutiveReportBuilder(tmp_path).build())
    )

    assert payload["project"]["name"] == "Puinave"
    assert payload["builder_version"] == "1.10.0"
