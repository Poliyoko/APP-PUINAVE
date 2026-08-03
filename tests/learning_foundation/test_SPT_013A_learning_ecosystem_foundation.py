from __future__ import annotations

from sgoda.learning_foundation import (
    FoundationRequest,
    LearningEcosystemFoundation,
    dependency_gaps,
    phase_capabilities,
)


def test_SPT_013A_has_six_capabilities() -> None:
    assert len(phase_capabilities()) == 6


def test_SPT_013A_starts_with_SPT_013() -> None:
    assert phase_capabilities()[0].code == "SPT-013"


def test_SPT_013A_ends_with_SPT_018() -> None:
    assert phase_capabilities()[-1].code == "SPT-018"


def test_SPT_013A_all_capabilities_are_native() -> None:
    assert all(item.native for item in phase_capabilities())


def test_SPT_013A_has_no_dependency_gaps() -> None:
    assert dependency_gaps() == ()


def test_SPT_013A_status_is_operational() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.status == "ok"
    assert response.data["component"] == "SPT-013A"


def test_SPT_013A_declares_phase_four() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.data["phase"] == "Fase Tecnológica IV"


def test_SPT_013A_declares_open_technology() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.data["freeOpenTechnology"] is True
    assert response.data["mandatoryProprietaryDependencies"] == []


def test_SPT_013A_preserves_no_invention() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.no_invention is True
    assert response.data["noInvention"] is True


def test_SPT_013A_lists_capabilities() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="capabilities")
    )

    assert response.status == "ok"
    assert response.data["total"] == 6


def test_SPT_013A_validates_foundation() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="validate")
    )

    assert response.status == "ok"
    assert response.data["approved"] is True


def test_SPT_013A_rejects_unknown_operation() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="unknown")
    )

    assert response.status == "unsupported_operation"


def test_SPT_013A_is_deterministic() -> None:
    service = LearningEcosystemFoundation()
    request = FoundationRequest(operation="status")

    assert service.execute(request) == service.execute(request)


def test_SPT_013A_domains_are_complete() -> None:
    assert {item.domain for item in phase_capabilities()} == {
        "dictionary",
        "multimedia",
        "assessment",
        "analytics",
        "knowledge",
        "pedagogical_ai",
    }