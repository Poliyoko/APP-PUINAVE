import pytest

from sgoda.pmo.repository.mmgr.progress_metrics import (
    CLOSED_VERIFIED,
    DOCUMENT_ONLY,
    IMPLEMENTED_NOT_CLOSED,
    ProgressInput,
    ProgressValidationError,
    calculate_project_progress,
    measure,
)


def item(
    code,
    classification,
    progress,
    weight=1.0,
    phase="TECH",
    architecture="DMP",
    pending="",
):
    return ProgressInput(
        code=code,
        classification=classification,
        family="SPT",
        phase=phase,
        architecture=architecture,
        weight=weight,
        individual_progress=progress,
        pending_for_closure=pending,
    )


def test_closed_requires_100_percent():
    result = measure(
        item("SPT-001", CLOSED_VERIFIED, 100)
    )
    assert result.individual_progress == 100
    assert result.weighted_progress == 1.0


def test_closed_rejects_partial_progress():
    with pytest.raises(ProgressValidationError):
        measure(
            item("SPT-001", CLOSED_VERIFIED, 90)
        )


def test_open_rejects_100_percent():
    with pytest.raises(ProgressValidationError):
        measure(
            item(
                "SPT-002",
                IMPLEMENTED_NOT_CLOSED,
                100,
            )
        )


def test_invalid_progress_rejected():
    with pytest.raises(ProgressValidationError):
        measure(
            item("SPT-002", DOCUMENT_ONLY, 101)
        )


def test_negative_weight_rejected():
    with pytest.raises(ProgressValidationError):
        measure(
            item(
                "SPT-002",
                DOCUMENT_ONLY,
                50,
                weight=-1,
            )
        )


def test_weighted_global_progress():
    result = calculate_project_progress(
        (
            item(
                "SPT-001",
                CLOSED_VERIFIED,
                100,
                weight=3,
            ),
            item(
                "SPT-002",
                IMPLEMENTED_NOT_CLOSED,
                50,
                weight=1,
            ),
        )
    )

    assert result.total_weight == 4
    assert result.weighted_progress == 3.5
    assert result.global_progress == 87.5


def test_closed_percentage_is_separate_metric():
    result = calculate_project_progress(
        (
            item(
                "SPT-001",
                CLOSED_VERIFIED,
                100,
                weight=9,
            ),
            item(
                "SPT-002",
                DOCUMENT_ONLY,
                50,
                weight=1,
            ),
        )
    )

    assert result.closed_percentage == 50.0
    assert result.global_progress == 95.0


def test_phase_aggregation():
    result = calculate_project_progress(
        (
            item(
                "A",
                CLOSED_VERIFIED,
                100,
                phase="BASE",
            ),
            item(
                "B",
                IMPLEMENTED_NOT_CLOSED,
                50,
                phase="BASE",
            ),
        )
    )

    assert result.by_phase["BASE"].progress == 75.0
    assert result.by_phase["BASE"].deliverables == 2


def test_architecture_aggregation():
    result = calculate_project_progress(
        (
            item(
                "A",
                CLOSED_VERIFIED,
                100,
                architecture="Builder",
            ),
            item(
                "B",
                IMPLEMENTED_NOT_CLOSED,
                25,
                architecture="DMP",
            ),
        )
    )

    assert result.by_architecture["Builder"].progress == 100
    assert result.by_architecture["DMP"].progress == 25


def test_pending_for_closure_is_preserved():
    result = measure(
        item(
            "SPT-002",
            IMPLEMENTED_NOT_CLOSED,
            80,
            pending="Publication",
        )
    )

    assert result.pending_for_closure == "Publication"


def test_zero_weight_does_not_break_calculation():
    result = calculate_project_progress(
        (
            item(
                "A",
                DOCUMENT_ONLY,
                50,
                weight=0,
            ),
        )
    )

    assert result.global_progress == 0
    assert result.total_weight == 0


def test_empty_project_is_zero():
    result = calculate_project_progress(())

    assert result.global_progress == 0
    assert result.closed_percentage == 0
    assert result.deliverables == 0