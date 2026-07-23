import pytest

from sgoda.dmp import (
    ALLOWED_WORK_STATUS_TRANSITIONS,
    DmpRegistryService,
    InvalidStateTransition,
    Project,
    WorkStatus,
)


@pytest.mark.parametrize(
    ("current_status", "new_status"),
    [
        (WorkStatus.PLANNED, WorkStatus.IN_PROGRESS),
        (WorkStatus.PLANNED, WorkStatus.CANCELLED),
        (WorkStatus.IN_PROGRESS, WorkStatus.BLOCKED),
        (WorkStatus.IN_PROGRESS, WorkStatus.COMPLETED),
        (WorkStatus.IN_PROGRESS, WorkStatus.CANCELLED),
        (WorkStatus.BLOCKED, WorkStatus.IN_PROGRESS),
        (WorkStatus.BLOCKED, WorkStatus.CANCELLED),
    ],
)
def test_allowed_lifecycle_transitions(
    current_status: WorkStatus,
    new_status: WorkStatus,
) -> None:
    record = Project(
        identifier="PRJ-SGODA",
        name="SGODA-PUINAVE",
        status=current_status,
    )

    transitioned = record.transition_to(new_status)

    assert transitioned.status is new_status
    assert transitioned.identifier == record.identifier
    assert transitioned is not record
    assert record.status is current_status
    assert transitioned.updated_at >= record.updated_at


@pytest.mark.parametrize(
    ("current_status", "new_status"),
    [
        (WorkStatus.PLANNED, WorkStatus.COMPLETED),
        (WorkStatus.PLANNED, WorkStatus.BLOCKED),
        (WorkStatus.IN_PROGRESS, WorkStatus.PLANNED),
        (WorkStatus.BLOCKED, WorkStatus.COMPLETED),
        (WorkStatus.COMPLETED, WorkStatus.IN_PROGRESS),
        (WorkStatus.COMPLETED, WorkStatus.CANCELLED),
        (WorkStatus.CANCELLED, WorkStatus.IN_PROGRESS),
        (WorkStatus.CANCELLED, WorkStatus.COMPLETED),
    ],
)
def test_forbidden_lifecycle_transitions_raise_domain_error(
    current_status: WorkStatus,
    new_status: WorkStatus,
) -> None:
    record = Project(
        identifier="PRJ-SGODA",
        name="SGODA-PUINAVE",
        status=current_status,
    )

    with pytest.raises(
        InvalidStateTransition,
        match=f"{current_status.value} -> {new_status.value}",
    ):
        record.transition_to(new_status)


@pytest.mark.parametrize("status", tuple(WorkStatus))
def test_transition_to_same_status_is_rejected(
    status: WorkStatus,
) -> None:
    record = Project(
        identifier="PRJ-SGODA",
        name="SGODA-PUINAVE",
        status=status,
    )

    with pytest.raises(InvalidStateTransition):
        record.transition_to(status)


def test_transition_matrix_covers_every_work_status() -> None:
    assert set(ALLOWED_WORK_STATUS_TRANSITIONS) == set(WorkStatus)


def test_registry_uses_domain_lifecycle_and_preserves_record_on_failure() -> None:
    events = []
    service = DmpRegistryService(event_handler=events.append)
    original = service.register(
        Project(
            identifier="PRJ-SGODA",
            name="SGODA-PUINAVE",
        )
    )

    with pytest.raises(InvalidStateTransition):
        service.update_status(
            original.identifier,
            WorkStatus.COMPLETED,
        )

    stored = service.require(original.identifier)

    assert stored == original
    assert stored.status is WorkStatus.PLANNED
    assert [event.event_type for event in events] == [
        "dmp.record.created",
    ]


def test_registry_emits_previous_status_after_valid_transition() -> None:
    events = []
    service = DmpRegistryService(event_handler=events.append)
    service.register(
        Project(
            identifier="PRJ-SGODA",
            name="SGODA-PUINAVE",
        )
    )

    updated = service.update_status(
        "PRJ-SGODA",
        WorkStatus.IN_PROGRESS,
    )

    assert updated.status is WorkStatus.IN_PROGRESS
    assert events[-1].event_type == "dmp.record.status_changed"
    assert events[-1].payload["previous_status"] == "planned"
    assert events[-1].payload["status"] == "in_progress"
