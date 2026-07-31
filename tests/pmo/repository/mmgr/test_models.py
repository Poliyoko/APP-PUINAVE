"""Pruebas unitarias del modelo de dominio MMGR-001A."""

from __future__ import annotations

import pytest

from sgoda.pmo.repository.mmgr.models import (
    Asset,
    AssetStatus,
    Domain,
    GitPolicy,
    RiskLevel,
    Traceability,
)


def make_asset(**changes: object) -> Asset:
    payload: dict[str, object] = {
        "asset_id": "MMGR-000001",
        "name": "MMGR domain model",
        "path": "src/sgoda/pmo/repository/mmgr/models.py",
        "domain": Domain.PMO,
        "status": AssetStatus.IN_DEVELOPMENT,
        "git_policy": GitPolicy.VERSIONED,
        "owner": "PMO Digital / Repository Governance",
        "risk": RiskLevel.HIGH,
        "traceability": Traceability(
            spb=("SPB-005.2-F002A",),
            tests=("tests/pmo/repository/mmgr/test_models.py",),
        ),
        "dependencies": (),
        "tags": ("mmgr", "governance"),
        "observations": "Modelo inicial.",
    }
    payload.update(changes)
    return Asset(**payload)


def test_asset_accepts_valid_data() -> None:
    asset = make_asset()

    assert asset.asset_id == "MMGR-000001"
    assert asset.domain is Domain.PMO
    assert asset.status is AssetStatus.IN_DEVELOPMENT
    assert asset.git_policy is GitPolicy.VERSIONED
    assert asset.risk is RiskLevel.HIGH


def test_asset_normalizes_windows_path_and_text() -> None:
    asset = make_asset(
        name="  Modelo MMGR  ",
        path=r"src\sgoda\pmo\repository\mmgr\models.py",
        owner="  PMO Digital  ",
        observations="  Evidencia inicial.  ",
    )

    assert asset.name == "Modelo MMGR"
    assert asset.path == "src/sgoda/pmo/repository/mmgr/models.py"
    assert asset.owner == "PMO Digital"
    assert asset.observations == "Evidencia inicial."


@pytest.mark.parametrize(
    "asset_id",
    [
        "MMGR-1",
        "MMGR-00001",
        "MMGR-0000001",
        "mmgr-000001",
        "ASSET-000001",
        "",
    ],
)
def test_asset_rejects_invalid_identifier(asset_id: str) -> None:
    with pytest.raises(ValueError, match="Identificador MMGR inválido"):
        make_asset(asset_id=asset_id)


def test_asset_rejects_absolute_path() -> None:
    with pytest.raises(ValueError, match="relativa"):
        make_asset(path="/src/sgoda/file.py")


def test_asset_rejects_parent_path_escape() -> None:
    with pytest.raises(ValueError, match="escapar"):
        make_asset(path="../secrets.txt")


def test_asset_rejects_self_dependency() -> None:
    with pytest.raises(ValueError, match="depender de sí mismo"):
        make_asset(dependencies=("MMGR-000001",))


def test_asset_rejects_invalid_dependency_identifier() -> None:
    with pytest.raises(ValueError, match="dependencias"):
        make_asset(dependencies=("INVALID-001",))


def test_traceability_rejects_duplicate_values() -> None:
    with pytest.raises(ValueError, match="duplicados"):
        Traceability(spb=("SPB-005.2", "SPB-005.2"))


def test_asset_round_trip_dictionary() -> None:
    original = make_asset()
    restored = Asset.from_dict(original.to_dict())

    assert restored == original


def test_to_dict_is_json_compatible() -> None:
    payload = make_asset().to_dict()

    assert payload["domain"] == "pmo"
    assert payload["status"] == "in_development"
    assert payload["git_policy"] == "versioned"
    assert payload["risk"] == "high"
    assert payload["traceability"]["spb"] == ["SPB-005.2-F002A"]
    assert payload["tags"] == ["mmgr", "governance"]


def test_domain_catalog_contains_expected_values() -> None:
    assert Domain.KERNEL.value == "kernel"
    assert Domain.DOCUMENTATION.value == "documentation"
    assert Domain.EVIDENCE.value == "evidence"
    assert Domain.UNKNOWN.value == "unknown"


def test_asset_is_immutable() -> None:
    asset = make_asset()

    with pytest.raises(AttributeError):
        asset.name = "Modified"  # type: ignore[misc]