from sgoda.pmo.repository.mmgr.progress_policy import (
    infer_architecture,
)


def test_flutter_implementation_path_maps_to_mobile():
    architecture, score = infer_architecture(
        ("src/sgoda/mobile/flutter/client.py",),
        family="SPT",
    )

    assert architecture == "Mobile"
    assert score >= 10


def test_flutter_contract_maps_to_mobile():
    architecture, score = infer_architecture(
        ("src/sgoda/operational_platform/flutter_contracts.py",),
        family="SPT",
    )

    assert architecture == "Mobile"
    assert score >= 10


def test_flutter_client_security_maps_to_mobile():
    architecture, score = infer_architecture(
        (
            "config/integration/spt0246/"
            "flutter-client-security-policy.json",
        ),
        family="SPT",
    )

    assert architecture == "Mobile"
    assert score >= 10


def test_web_portal_path_maps_to_portal_web():
    architecture, score = infer_architecture(
        ("src/sgoda/portal_web/frontend/app.py",),
        family="SPT",
    )

    assert architecture == "Portal Web"
    assert score >= 10


def test_web_identity_maps_to_portal_web():
    architecture, score = infer_architecture(
        ("artifacts/identity/SPT-005/exports/web-identity.json",),
        family="SPT",
    )

    assert architecture == "Portal Web"
    assert score >= 10


def test_generic_flutter_document_does_not_force_mobile():
    architecture, score = infer_architecture(
        (
            "docs/05_Fase_Tecnologica/SPT-007/"
            "SPT-007C-Pruebas-Criterios-Aceptacion.md",
        ),
        family="SPT",
    )

    assert architecture != "Mobile"


def test_generic_web_document_does_not_force_portal_web():
    architecture, score = infer_architecture(
        ("docs/architecture/web-guidance.md",),
        family="SPT",
    )

    assert architecture != "Portal Web"


def test_builder_family_contract_remains_compatible():
    architecture, score = infer_architecture(
        (),
        family="SPB",
    )

    assert architecture == "Builder"
    assert score == 2