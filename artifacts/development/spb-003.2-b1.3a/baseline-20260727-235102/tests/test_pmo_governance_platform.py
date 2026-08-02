from pathlib import Path

import pytest

from sgoda.pmo import PmoStatus, load_project_model, validate_project_model
from sgoda.pmo.generators import dashboard_markdown, dmp_markdown, executive_report_markdown, technical_document_markdown


def test_project_model_loads_from_single_source() -> None:
    model = load_project_model(Path("knowledge/project_model.json"))

    assert model.project.identifier == "SGODA-PUINAVE"
    assert model.total_deliverables == 9
    assert model.closed_deliverables >= 8
    assert model.average_progress > 90


def test_deliverables_have_executive_language() -> None:
    model = load_project_model(Path("knowledge/project_model.json"))

    for deliverable in model.deliverables:
        assert deliverable.purpose
        assert deliverable.benefit
        assert deliverable.executive_name
        assert 0 <= deliverable.progress <= 100


def test_governance_validation_accepts_baseline_model() -> None:
    model = load_project_model(Path("knowledge/project_model.json"))
    validate_project_model(model)


def test_generators_use_same_model() -> None:
    model = load_project_model(Path("knowledge/project_model.json"))

    dashboard = dashboard_markdown(model)
    dmp = dmp_markdown(model)
    report = executive_report_markdown(model)
    technical = technical_document_markdown(model)

    assert "Dashboard Ejecutivo" in dashboard
    assert "DMP v2.0" in dmp
    assert "Informe Ejecutivo" in report
    assert "Plataforma de Gobierno Documental" in technical
    assert "SPB-003" in dashboard
    assert "SPB-003" in dmp


def test_status_enum_contains_declared_and_verified_states() -> None:
    assert PmoStatus.COMPLETED_DECLARED.value == "completed_declared"
    assert PmoStatus.COMPLETED_VERIFIED.value == "completed_verified"
