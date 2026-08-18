from sgoda.pmo.repository.mmgr.progress_policy import (
    ARCHITECTURE_WEIGHTS,
    assign_strategic_weights,
    decide,
    infer_architecture,
)


def test_architecture_weights_total_100():
    assert sum(ARCHITECTURE_WEIGHTS.values()) == 100


def test_multimedia_implementation_beats_pmo_evidence():
    architecture, score = infer_architecture(
        (
            "src/sgoda/multimedia/audio/service.py",
            "artifacts/pmo/SPT-003/evidence.json",
        ),
        family="SPT",
    )

    assert architecture == "Multimedia"
    assert score > 0


def test_api_implementation_beats_dashboard_reference():
    architecture, score = infer_architecture(
        (
            "src/sgoda/api/routers/words.py",
            "artifacts/pmo/dashboard-summary.json",
        ),
        family="SPT",
    )

    assert architecture == "API"


def test_builder_family_is_builder():
    architecture, _ = infer_architecture(
        (
            "docs/SPB-003.2.md",
        ),
        family="SPB",
    )

    assert architecture == "Builder"


def test_audio_family_is_multimedia():
    architecture, _ = infer_architecture(
        (
            "tools/sgoda_audio_manager/v0.3.0/README.md",
        ),
        family="AUDIO",
    )

    assert architecture == "Multimedia"


def test_visible_family_is_portal_web():
    architecture, _ = infer_architecture(
        (),
        family="VISIBLE",
    )

    assert architecture == "Portal Web"


def test_pure_governance_maps_to_dmp():
    architecture, _ = infer_architecture(
        (
            "src/sgoda/pmo/repository/mmgr/report.py",
        ),
        family="SGD",
    )

    assert architecture == "DMP"


def test_unresolved_technical_record_falls_back_to_nucleo():
    architecture, score = infer_architecture(
        (),
        family="SPT",
    )

    assert architecture == "Nucleo"
    assert score == 0


def test_historical_records_receive_zero_weight():
    historical = decide(
        code="SGD-001",
        family="SGD",
        classification="HISTORICAL_REFERENCE",
        source_paths=("docs/SGD-001.md",),
    )

    active = decide(
        code="SGD-002",
        family="SGD",
        classification="CLOSED_VERIFIED",
        source_paths=(
            "src/sgoda/pmo/repository/mmgr/state.py",
        ),
    )

    weighted = assign_strategic_weights(
        (historical, active)
    )

    values = {
        item.code: item.weight
        for item in weighted
    }

    assert values["SGD-001"] == 0
    assert values["SGD-002"] > 0


def test_architecture_budget_is_distributed_equally():
    first = decide(
        code="A",
        family="AUDIO",
        classification="CLOSED_VERIFIED",
        source_paths=("tools/audio/a.wav",),
    )

    second = decide(
        code="B",
        family="AUDIO",
        classification="IMPLEMENTED_NOT_CLOSED",
        source_paths=("tools/audio/b.wav",),
    )

    weighted = assign_strategic_weights(
        (first, second)
    )

    assert weighted[0].weight == 6.0
    assert weighted[1].weight == 6.0