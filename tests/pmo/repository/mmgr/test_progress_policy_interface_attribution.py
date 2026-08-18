from sgoda.pmo.repository.mmgr.progress_policy import (
    decide,
    infer_architecture,
)


def test_decide_respects_strong_flutter_client_mobile_signal():
    sources = (
        "config/integration/spt0246/"
        "flutter-client-security-policy.json",
    )

    inferred_architecture, inferred_score = infer_architecture(
        sources,
        family="SPT",
    )

    decision = decide(
        code="SPT-024.6",
        family="SPT",
        classification="CLOSED_VERIFIED",
        source_paths=sources,
    )

    assert inferred_architecture == "Mobile"
    assert inferred_score == 10

    assert decision.architecture == "Mobile"
    assert decision.architecture_score == 10
    assert decision.architecture_basis == "FUNCTIONAL"
    assert decision.individual_progress == 100.0


def test_decide_respects_strong_flutter_contract_mobile_signal():
    sources = (
        "src/sgoda/operational_platform/flutter_contracts.py",
    )

    inferred_architecture, inferred_score = infer_architecture(
        sources,
        family="SPT",
    )

    decision = decide(
        code="SPT-011",
        family="SPT",
        classification="CLOSED_VERIFIED",
        source_paths=sources,
    )

    assert inferred_architecture == "Mobile"
    assert inferred_score == 10

    assert decision.architecture == "Mobile"
    assert decision.architecture_score == 10
    assert decision.architecture_basis == "FUNCTIONAL"
    assert decision.individual_progress == 100.0


def test_decide_does_not_promote_weak_flutter_documentation():
    sources = (
        "docs/03_ADR/ADR-004-Uso-de-Flutter.md",
    )

    decision = decide(
        code="ADR-004",
        family="ADR",
        classification="DOCUMENT_ONLY",
        source_paths=sources,
    )

    assert decision.architecture != "Mobile"


def test_decide_preserves_non_interface_fallback():
    sources = (
        "artifacts/pmo/example-audit.json",
    )

    inferred_architecture, inferred_score = infer_architecture(
        sources,
        family="SGD",
    )

    decision = decide(
        code="SGD-TEST",
        family="SGD",
        classification="CLOSED_VERIFIED",
        source_paths=sources,
    )

    assert decision.architecture == inferred_architecture
    assert decision.architecture_score == inferred_score