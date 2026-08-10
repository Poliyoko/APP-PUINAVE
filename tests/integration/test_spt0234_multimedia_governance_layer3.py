import pytest

from sgoda.integration.spt0234.handoff import build_fld_oda_handoff
from sgoda.integration.spt0234.layer3 import Spt0234Layer3GovernanceService
from sgoda.integration.spt0234.manifest import build_completeness_manifest
from sgoda.integration.spt0234.quality import review_resource


RESOURCE_TYPES = (
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "audio_it",
)


def resource(resource_type):
    return {
        "resource_id": f"MM-{resource_type}",
        "resource_type": resource_type,
        "status": "GENERATED_LOCAL",
        "sha256": "A" * 64,
        "output_path": f"media/LEX-001/{resource_type}.bin",
        "validation": {"valid": True},
    }


def approval():
    return {
        resource_type: {
            "approve": True,
            "reviewer": "reviewer-01",
            "reason": "validado",
        }
        for resource_type in RESOURCE_TYPES
    }


def test_resource_approval_requires_human_reviewer():
    with pytest.raises(ValueError):
        review_resource(
            resource("image"),
            approve=True,
            reviewer="",
            reason="ok",
        )


def test_resource_approval_requires_reason():
    with pytest.raises(ValueError):
        review_resource(
            resource("image"),
            approve=True,
            reviewer="r1",
            reason="",
        )


def test_invalid_resource_cannot_be_approved():
    bad = resource("image")
    bad["validation"] = {"valid": False}
    with pytest.raises(ValueError):
        review_resource(
            bad,
            approve=True,
            reviewer="r1",
            reason="ok",
        )


def test_approved_resource_status_is_approved():
    decision = review_resource(
        resource("image"),
        approve=True,
        reviewer="r1",
        reason="ok",
    )
    assert decision.status == "APPROVED"
    assert decision.approved is True


def test_rejected_resource_status_is_rejected():
    decision = review_resource(
        resource("image"),
        approve=False,
        reviewer="r1",
        reason="quality",
    )
    assert decision.status == "REJECTED"
    assert decision.approved is False


def test_complete_manifest_requires_five_approved_resources():
    decisions = [
        review_resource(
            resource(rt),
            approve=True,
            reviewer="r1",
            reason="ok",
        ).to_dict()
        for rt in RESOURCE_TYPES
    ]
    manifest = build_completeness_manifest("LEX-001", decisions)
    assert manifest.complete is True
    assert len(manifest.approved_resources) == 5


def test_manifest_detects_missing_resource():
    decisions = [
        review_resource(
            resource(rt),
            approve=True,
            reviewer="r1",
            reason="ok",
        ).to_dict()
        for rt in RESOURCE_TYPES[:-1]
    ]
    manifest = build_completeness_manifest("LEX-001", decisions)
    assert manifest.complete is False
    assert manifest.missing_resources == ("audio_it",)


def test_manifest_detects_rejected_resource():
    decisions = []
    for rt in RESOURCE_TYPES:
        decisions.append(
            review_resource(
                resource(rt),
                approve=(rt != "image"),
                reviewer="r1",
                reason="ok",
            ).to_dict()
        )
    manifest = build_completeness_manifest("LEX-001", decisions)
    assert manifest.complete is False
    assert manifest.rejected_resources == ("image",)


def test_manifest_is_deterministic():
    decisions = [
        review_resource(
            resource(rt),
            approve=True,
            reviewer="r1",
            reason="ok",
        ).to_dict()
        for rt in RESOURCE_TYPES
    ]
    one = build_completeness_manifest("LEX-001", decisions)
    two = build_completeness_manifest("LEX-001", decisions)
    assert one.manifest_sha256 == two.manifest_sha256


def test_duplicate_resource_decision_is_rejected():
    decisions = [
        review_resource(resource("image"), approve=True, reviewer="r1", reason="ok").to_dict(),
        review_resource(resource("image"), approve=True, reviewer="r2", reason="ok").to_dict(),
    ]
    with pytest.raises(ValueError):
        build_completeness_manifest("LEX-001", decisions)


def test_handoff_requires_complete_manifest():
    with pytest.raises(ValueError):
        build_fld_oda_handoff(
            lexical_id="LEX-001",
            puinave="AMDA",
            category_id="CAT-NATURE",
            manifest={"complete": False, "manifest_sha256": "X"},
            approved_resources=[],
        )


def test_handoff_requires_exactly_five_resources():
    with pytest.raises(ValueError):
        build_fld_oda_handoff(
            lexical_id="LEX-001",
            puinave="AMDA",
            category_id="CAT-NATURE",
            manifest={"complete": True, "manifest_sha256": "X"},
            approved_resources=[resource("image")],
        )


def test_full_bundle_is_ready_for_fld_oda():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert result["status"] == "READY_FOR_FLD_ODA"
    assert result["manifest"]["complete"] is True
    assert result["handoff"]["next_component"] == "SPT-023.5"


def test_bundle_with_missing_decision_requires_review():
    service = Spt0234Layer3GovernanceService()
    decisions = approval()
    decisions.pop("audio_it")
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=decisions,
    )
    assert result["status"] == "MULTIMEDIA_REVIEW_REQUIRED"
    assert result["handoff"] is None


def test_bundle_with_rejection_requires_review():
    service = Spt0234Layer3GovernanceService()
    decisions = approval()
    decisions["image"]["approve"] = False
    decisions["image"]["reason"] = "rechazada"
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=decisions,
    )
    assert result["status"] == "MULTIMEDIA_REVIEW_REQUIRED"


def test_final_handoff_disables_paid_api():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert result["handoff"]["paid_api_used"] is False


def test_final_handoff_contains_five_resources():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert len(result["handoff"]["resources"]) == 5


def test_final_handoff_targets_spt0235():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert result["next_component"] == "SPT-023.5"
