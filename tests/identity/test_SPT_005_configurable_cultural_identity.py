"""Pruebas SPT-005 de identidad cultural configurable."""

import json
from pathlib import Path

import pytest

from sgoda.identity.exporter import (
    export_api,
    export_flutter,
    export_web,
)
from sgoda.identity.models import CulturalApproval, IdentityProfile
from sgoda.identity.repository import IdentityRepository
from sgoda.identity.service import (
    IdentityGovernanceError,
    IdentityService,
)


def _baseline() -> IdentityProfile:
    return IdentityProfile(
        identity_id="sgoda-puinave-baseline",
        technical_name="SGODA-PUINAVE",
        public_name="SGODA-PUINAVE",
        app_name="SGODA-PUINAVE",
        assistant_name="Asistente Virtual SGODA",
        puinave_name=None,
        spanish_name="Plataforma Digital Puinave",
        english_name="Puinave Digital Platform",
        slogan=(
            "Tecnología para preservar la memoria del pueblo Puinave."
        ),
        locale_default="es",
        approval=CulturalApproval(status="baseline"),
    )


def _approved() -> IdentityProfile:
    return IdentityProfile(
        identity_id="nombre-puinave-aprobado",
        technical_name="SGODA-PUINAVE",
        public_name="NOMBRE VALIDADO",
        app_name="NOMBRE VALIDADO",
        assistant_name="Asistente NOMBRE VALIDADO",
        puinave_name="NOMBRE VALIDADO",
        spanish_name="Plataforma Digital Puinave",
        english_name="Puinave Digital Platform",
        slogan="Identidad aprobada por el pueblo Puinave.",
        locale_default="es",
        approval=CulturalApproval(
            status="approved",
            approved_by="Autoridad Cultural Puinave",
            approval_date="2026-08-02",
            approval_document="ACTA-CULTURAL-001",
            community_scope="Pueblo Puinave",
        ),
    )


def _service(tmp_path: Path) -> IdentityService:
    return IdentityService(
        repository=IdentityRepository(tmp_path / "identities.json"),
        history_path=tmp_path / "history.jsonl",
    )


def test_SPT_005_preserva_identidad_tecnica(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()

    service.register(profile)

    assert (
        service.repository.get(profile.identity_id).technical_name
        == "SGODA-PUINAVE"
    )


def test_SPT_005_rechaza_cambio_identidad_tecnica(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()
    profile.technical_name = "OTRO-NOMBRE"

    with pytest.raises(IdentityGovernanceError):
        service.register(profile)


def test_SPT_005_registra_identidad_base(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.register(_baseline())

    assert len(service.repository.list_profiles()) == 1


def test_SPT_005_no_activa_nombre_puinave_sin_aprobacion(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()
    profile.identity_id = "propuesta-puinave"
    profile.puinave_name = "PROPUESTA"
    profile.approval = CulturalApproval(status="pending")

    with pytest.raises(IdentityGovernanceError):
        service.register(profile)


def test_SPT_005_activa_identidad_aprobada(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.register(_baseline())
    service.register(_approved())

    active = service.activate(
        "nombre-puinave-aprobado",
        changed_by="PMO Digital",
        reason="Acta cultural aprobada.",
    )

    assert active.active is True
    assert active.puinave_name == "NOMBRE VALIDADO"


def test_SPT_005_desactiva_identidad_anterior(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    baseline = _baseline()
    service.register(baseline)
    service.activate(
        baseline.identity_id,
        changed_by="PMO Digital",
        reason="Línea base.",
    )
    service.register(_approved())
    service.activate(
        "nombre-puinave-aprobado",
        changed_by="PMO Digital",
        reason="Nueva identidad.",
    )

    assert service.repository.get(baseline.identity_id).active is False


def test_SPT_005_registra_historial(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.register(_baseline())
    service.activate(
        "sgoda-puinave-baseline",
        changed_by="PMO Digital",
        reason="Activación inicial.",
    )

    event = json.loads(
        (tmp_path / "history.jsonl").read_text(
            encoding="utf-8"
        ).strip()
    )
    assert event["new_identity_id"] == "sgoda-puinave-baseline"


def test_SPT_005_exporta_flutter(tmp_path: Path) -> None:
    path = export_flutter(_approved(), tmp_path / "flutter.json")
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["appName"] == "NOMBRE VALIDADO"
    assert payload["assistantName"] == (
        "Asistente NOMBRE VALIDADO"
    )


def test_SPT_005_exporta_web(tmp_path: Path) -> None:
    path = export_web(_approved(), tmp_path / "web.json")
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["title"] == "NOMBRE VALIDADO"
    assert payload["technicalIdentity"] == "SGODA-PUINAVE"


def test_SPT_005_exporta_api(tmp_path: Path) -> None:
    path = export_api(_approved(), tmp_path / "api.json")
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["approval_status"] == "approved"
    assert payload["technical_name"] == "SGODA-PUINAVE"


def test_SPT_005_crea_propuesta_pendiente(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    proposal = service.create_pending_puinave_proposal(
        identity_id="propuesta-comunitaria",
        proposed_name="Nombre por validar",
        proposed_by="Equipo del proyecto",
    )

    assert proposal.approval.status == "pending"
    assert proposal.puinave_name is None


def test_SPT_005_rechaza_identificador_invalido(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()
    profile.identity_id = "Nombre Con Espacios"

    with pytest.raises(IdentityGovernanceError):
        service.register(profile)