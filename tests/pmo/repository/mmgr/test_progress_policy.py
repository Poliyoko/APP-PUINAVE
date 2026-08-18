from sgoda.pmo.repository.mmgr.progress_policy import (
    INSTITUTIONAL_ARCHITECTURES,
    classification_progress,
    decide,
    infer_architecture,
    phase_for_family,
    to_progress_input,
)


def test_closed_is_100_percent():
    assert classification_progress("CLOSED_VERIFIED") == 100


def test_implemented_not_closed_is_80_percent():
    assert (
        classification_progress(
            "IMPLEMENTED_NOT_CLOSED"
        )
        == 80
    )


def test_document_only_is_partial_not_closed():
    assert classification_progress("DOCUMENT_ONLY") == 25


def test_historical_reference_does_not_inflate_progress():
    assert (
        classification_progress(
            "HISTORICAL_REFERENCE"
        )
        == 0
    )


def test_spt_maps_to_technological_phase():
    assert phase_for_family("SPT") == "Fase Tecnologica"


def test_spb_maps_to_base_phase():
    assert phase_for_family("SPB") == "Construccion Base"


def test_sgd_maps_to_governance_phase():
    assert (
        phase_for_family("SGD")
        == "Gobierno Institucional"
    )


def test_audio_maps_to_multimedia():
    architecture, score = infer_architecture(
        (
            "tools/sgoda_audio_manager/v0.3.0/README.md",
        ),
        family="AUDIO",
    )

    assert architecture == "Multimedia"
    assert score > 0


def test_visible_maps_to_portal_web():
    architecture, score = infer_architecture(
        (
            "src/sgoda/visible/application.py",
        ),
        family="VISIBLE",
    )

    assert architecture == "Portal Web"
    assert score > 0


def test_builder_family_has_builder_hint():
    architecture, score = infer_architecture(
        (),
        family="SPB",
    )

    assert architecture == "Builder"
    assert score == 2


def test_dmp_path_maps_to_dmp():
    architecture, score = infer_architecture(
        (
            "src/sgoda/pmo/repository/mmgr/"
            "progress_metrics.py",
        ),
        family="SPT",
    )

    assert architecture == "DMP"
    assert score > 0


def test_decision_preserves_neutral_weight():
    result = decide(
        code="SPT-022",
        family="SPT",
        classification="CLOSED_VERIFIED",
        source_paths=("src/sgoda/automation/platform.py",),
    )

    assert result.weight == 1.0
    assert result.individual_progress == 100


def test_decision_contains_pending_for_open_item():
    result = decide(
        code="SGODA-AUDIO",
        family="AUDIO",
        classification="IMPLEMENTED_NOT_CLOSED",
        source_paths=(
            "tools/sgoda_audio_manager/README.md",
        ),
    )

    assert result.pending_for_closure
    assert result.individual_progress == 80


def test_decision_converts_to_progress_input():
    decision = decide(
        code="REAL-25",
        family="REAL",
        classification="CLOSED_VERIFIED",
        source_paths=(
            "tools/sgoda_audio_manager/"
            "evidence/real-25/summary.json",
        ),
    )

    value = to_progress_input(decision)

    assert value.code == "REAL-25"
    assert value.individual_progress == 100


def test_architecture_contract_has_exactly_ten_areas():
    assert len(INSTITUTIONAL_ARCHITECTURES) == 10

    assert set(INSTITUTIONAL_ARCHITECTURES) == {
        "Nucleo",
        "Builder",
        "CCP",
        "API",
        "ODA",
        "Multimedia",
        "Mobile",
        "Portal Web",
        "IA",
        "DMP",
    }