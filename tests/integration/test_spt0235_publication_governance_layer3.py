import pytest

from sgoda.integration.spt0235.catalog import PublishedObjectCatalog
from sgoda.integration.spt0235.layer3 import Spt0235Layer3GovernanceService
from sgoda.integration.spt0235.manifest import build_publication_manifest
from sgoda.integration.spt0235.publication import review_for_publication
from sgoda.integration.spt0235.registry import FldOdaRegistry


def objects():
    resources = {
        resource_type: {
            "resource_id": f"MM-{resource_type}",
            "resource_type": resource_type,
            "output_path": f"media/LEX-001/{resource_type}.bin",
            "sha256": "A" * 64,
        }
        for resource_type in (
            "image",
            "audio_puinave",
            "audio_es",
            "audio_en",
            "audio_it",
        )
    }
    fld = {
        "object_type": "FLD",
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "multimedia_manifest_sha256": "M" * 64,
        "resources": resources,
        "fld_sha256": "F" * 64,
    }
    oda = {
        "object_type": "ODA",
        "lexical_id": "LEX-001",
        "source_fld_sha256": fld["fld_sha256"],
        "multimedia_manifest_sha256": fld["multimedia_manifest_sha256"],
        "oda_sha256": "O" * 64,
    }
    return fld, oda


def stored_version():
    fld, oda = objects()
    return {
        "version": 1,
        "fld": fld,
        "oda": oda,
        "version_sha256": "V" * 64,
    }


def test_publication_requires_reviewer():
    with pytest.raises(ValueError):
        review_for_publication(
            stored_version(),
            lexical_id="LEX-001",
            approve=True,
            reviewer="",
            reason="ok",
        )


def test_publication_requires_reason():
    with pytest.raises(ValueError):
        review_for_publication(
            stored_version(),
            lexical_id="LEX-001",
            approve=True,
            reviewer="r1",
            reason="",
        )


def test_publication_approval_status():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    )
    assert decision.status == "APPROVED_FOR_PUBLICATION"
    assert decision.approved is True


def test_publication_rejection_status():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=False,
        reviewer="r1",
        reason="rejected",
    )
    assert decision.status == "PUBLICATION_REJECTED"
    assert decision.approved is False


def test_publication_detects_lexical_mismatch():
    with pytest.raises(ValueError):
        review_for_publication(
            stored_version(),
            lexical_id="OTHER",
            approve=True,
            reviewer="r1",
            reason="approved",
        )


def test_manifest_requires_approved_decision():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=False,
        reviewer="r1",
        reason="rejected",
    ).to_dict()
    with pytest.raises(ValueError):
        build_publication_manifest(
            decision=decision,
            registry_validation={"references_valid": True},
        )


def test_manifest_requires_valid_references():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    with pytest.raises(ValueError):
        build_publication_manifest(
            decision=decision,
            registry_validation={"references_valid": False},
        )


def test_manifest_sha_is_deterministic():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    validation = {"references_valid": True}
    one = build_publication_manifest(
        decision=decision,
        registry_validation=validation,
    )
    two = build_publication_manifest(
        decision=decision,
        registry_validation=validation,
    )
    assert one["publication_manifest_sha256"] == two["publication_manifest_sha256"]


def test_catalog_publishes_manifest(tmp_path):
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    manifest = build_publication_manifest(
        decision=decision,
        registry_validation={"references_valid": True},
    )
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    result = catalog.publish(manifest)
    assert result["lexical_id"] == "LEX-001"
    assert result["version"] == 1


def test_catalog_reuses_identical_publication(tmp_path):
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    manifest = build_publication_manifest(
        decision=decision,
        registry_validation={"references_valid": True},
    )
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    catalog.publish(manifest)
    second = catalog.publish(manifest)
    assert second["reused"] is True


def test_catalog_query_latest(tmp_path):
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    manifest = build_publication_manifest(
        decision=decision,
        registry_validation={"references_valid": True},
    )
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    catalog.publish(manifest)
    assert catalog.get("LEX-001")["version"] == 1


def test_catalog_query_unknown_returns_none(tmp_path):
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    assert catalog.get("UNKNOWN") is None


def seed_registry(path):
    fld, oda = objects()
    registry = FldOdaRegistry(path)
    registry.save_entry(
        lexical_id="LEX-001",
        fld=fld,
        oda=oda,
    )
    return registry


def test_layer3_approved_flow_publishes(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete and validated",
        approve=True,
    )
    assert result["status"] == "PUBLISHED_FLD_ODA"
    assert result["spt0235_scope_complete"] is True


def test_layer3_rejection_does_not_publish(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="not ready",
        approve=False,
    )
    assert result["status"] == "PUBLICATION_REJECTED"
    assert result["published_record"] is None


def test_layer3_requires_existing_object(tmp_path):
    service = Spt0235Layer3GovernanceService(
        registry_path=tmp_path / "registry.json",
        published_catalog_path=tmp_path / "published.json",
    )
    with pytest.raises(ValueError):
        service.review_and_publish(
            lexical_id="LEX-404",
            reviewer="reviewer-01",
            reason="x",
            approve=True,
        )


def test_layer3_preserves_reference_validation(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete",
        approve=True,
    )
    assert result["reference_validation"]["references_valid"] is True


def test_layer3_disables_paid_api(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete",
        approve=True,
    )
    assert result["paid_api_used"] is False


def test_layer3_points_to_spt0236(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete",
        approve=True,
    )
    assert result["next_component"] == "SPT-023.6"
