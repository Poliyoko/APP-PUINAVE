import pytest

from sgoda.dmp import (
    DmpRegistryService,
    EvidenceType,
    InMemoryDmpRepository,
    Project,
    WorkStatus,
)


def test_register_and_complete_record_emits_events() -> None:
    events = []
    service = DmpRegistryService(event_handler=events.append)
    project = Project(identifier="PRJ-SGODA", name="SGODA-PUINAVE")

    service.register(project)
    completed = service.update_status("prj-sgoda", WorkStatus.COMPLETED)

    assert completed.status is WorkStatus.COMPLETED
    assert [event.event_type for event in events] == [
        "dmp.record.created",
        "dmp.record.status_changed",
    ]
    assert events[1].payload["previous_status"] == "planned"


def test_duplicate_identifier_is_rejected() -> None:
    service = DmpRegistryService()
    project = Project(identifier="PRJ-SGODA", name="SGODA-PUINAVE")
    service.register(project)

    with pytest.raises(ValueError, match="Ya existe"):
        service.register(project)


def test_attach_evidence_creates_completed_record() -> None:
    service = DmpRegistryService()

    evidence = service.attach_evidence(
        identifier="EVD-003.1",
        spb_id="SPB-003.1",
        name="Commit funcional",
        evidence_type=EvidenceType.COMMIT,
        reference="abcdef1",
    )

    assert evidence.status is WorkStatus.COMPLETED
    assert service.require("EVD-003.1") == evidence


def test_repository_filters_by_type() -> None:
    repository = InMemoryDmpRepository()
    service = DmpRegistryService(repository)
    project = Project(identifier="PRJ-SGODA", name="SGODA-PUINAVE")
    service.register(project)

    assert service.list(Project) == (project,)
    assert service.list() == (project,)


def test_require_raises_for_unknown_record() -> None:
    service = DmpRegistryService()
    with pytest.raises(KeyError, match="No existe"):
        service.require("SPB-999")
