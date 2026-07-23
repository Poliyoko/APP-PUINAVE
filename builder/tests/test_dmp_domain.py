from datetime import date

import pytest

from sgoda.dmp import (
    Evidence,
    EvidenceType,
    ProductVersion,
    Project,
    Risk,
    Sprint,
    WorkStatus,
)


def test_project_normalizes_identifier_and_serializes_status() -> None:
    project = Project(identifier="prj-sgoda", name=" SGODA-PUINAVE ")

    assert project.identifier == "PRJ-SGODA"
    assert project.name == "SGODA-PUINAVE"
    assert project.to_dict()["status"] == "planned"
    assert project.created_at


def test_sprint_rejects_inverted_date_range() -> None:
    with pytest.raises(ValueError, match="fecha final"):
        Sprint(
            identifier="SPR-003",
            name="Sprint 003",
            project_id="PRJ-SGODA",
            version_id="VER-0.1.0",
            starts_on=date(2026, 7, 20),
            ends_on=date(2026, 7, 19),
        )


def test_version_requires_project_reference() -> None:
    version = ProductVersion(
        identifier="VER-0.1.0",
        name="Foundation",
        project_id="prj-sgoda",
        version="0.1.0",
    )
    assert version.project_id == "PRJ-SGODA"


def test_evidence_serializes_enum_fields() -> None:
    evidence = Evidence(
        identifier="EVD-003.1",
        name="Suite pytest",
        status=WorkStatus.COMPLETED,
        spb_id="SPB-003.1",
        evidence_type=EvidenceType.TEST,
        reference="pytest -q",
    )
    payload = evidence.to_dict()
    assert payload["status"] == "completed"
    assert payload["evidence_type"] == "test"


def test_risk_scores_are_bounded() -> None:
    with pytest.raises(ValueError, match="probability"):
        Risk(
            identifier="RSK-001",
            name="Riesgo inválido",
            project_id="PRJ-SGODA",
            probability=1.2,
        )
