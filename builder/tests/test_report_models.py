from sgoda.cli.main import main
from sgoda.operations import ExecutiveReportBuilder


def test_report_model_reuses_operation_status(tmp_path) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Reporte"]) == 0

    report = ExecutiveReportBuilder(tmp_path).build()

    assert report.project_name == "Reporte"
    assert report.status.builder_version == "1.8.0"
    assert report.metadata["model"] == "OperationStatus"
    assert report.health == report.status.health
    assert report.recommendations
