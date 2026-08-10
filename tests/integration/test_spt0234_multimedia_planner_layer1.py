import pytest

from sgoda.integration.spt0234.planner import build_multimedia_plan
from sgoda.integration.spt0234.policy import ROUTES, validate_policy
from sgoda.integration.spt0234.service import Spt0234Layer1Service


def record():
    return {
        "canonical_id": "LEX-001",
        "puinave": "AMDA",
        "selected_category_id": "CAT-NATURE",
    }


def test_policy_has_exactly_five_resources():
    validate_policy()
    assert len(ROUTES) == 5


def test_plan_has_image_and_four_audio_resources():
    result = build_multimedia_plan(record()).to_dict()
    assert {item["resource_type"] for item in result["plans"]} == {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }


def test_image_routes_to_existing_multimedia_stack():
    result = build_multimedia_plan(record()).to_dict()
    image = next(item for item in result["plans"] if item["resource_type"] == "image")
    assert image["route"] == "SPT-003A->SPT-003B->ADR-010"
    assert image["status"] == "READY_FOR_LOCAL_IMAGE"


def test_puinave_audio_requires_native_recording():
    result = build_multimedia_plan(record()).to_dict()
    audio = next(item for item in result["plans"] if item["resource_type"] == "audio_puinave")
    assert audio["provider_family"] == "NATIVE_HUMAN_RECORDING"
    assert audio["status"] == "NATIVE_RECORDING_REQUIRED"
    assert audio["requires_human_validation"] is True


@pytest.mark.parametrize(
    ("resource_type", "locale"),
    [
        ("audio_es", "es-CO"),
        ("audio_en", "en-US"),
        ("audio_it", "it-IT"),
    ],
)
def test_multilingual_audio_routes_to_free_local_tts(resource_type, locale):
    result = build_multimedia_plan(record()).to_dict()
    audio = next(item for item in result["plans"] if item["resource_type"] == resource_type)
    assert audio["language"] == locale
    assert audio["provider_family"] == "FREE_LOCAL_TTS"
    assert audio["route"] == "SPT-006A->SPT-003B->ADR-010"


def test_paid_api_is_disabled():
    result = build_multimedia_plan(record()).to_dict()
    assert result["paid_api_allowed"] is False
    assert result["automatic_external_calls"] is False


def test_existing_resource_is_reused():
    result = build_multimedia_plan(
        record(),
        existing_resources=[
            {"resource_type": "image", "status": "APPROVED"},
        ],
    ).to_dict()
    image = next(item for item in result["plans"] if item["resource_type"] == "image")
    assert image["status"] == "REUSE_EXISTING"
    assert image["existing_resource_reused"] is True


def test_invalid_existing_resource_is_not_reused():
    result = build_multimedia_plan(
        record(),
        existing_resources=[
            {"resource_type": "image", "status": "FAILED"},
        ],
    ).to_dict()
    image = next(item for item in result["plans"] if item["resource_type"] == "image")
    assert image["status"] == "READY_FOR_LOCAL_IMAGE"


def test_resource_ids_are_deterministic():
    one = build_multimedia_plan(record()).to_dict()
    two = build_multimedia_plan(record()).to_dict()
    assert [x["resource_id"] for x in one["plans"]] == [x["resource_id"] for x in two["plans"]]


def test_different_lexical_ids_have_different_resource_ids():
    one = build_multimedia_plan(record()).to_dict()
    other = record()
    other["canonical_id"] = "LEX-002"
    two = build_multimedia_plan(other).to_dict()
    assert [x["resource_id"] for x in one["plans"]] != [x["resource_id"] for x in two["plans"]]


def test_missing_lexical_id_is_rejected():
    item = record()
    item.pop("canonical_id")
    with pytest.raises(ValueError):
        build_multimedia_plan(item)


def test_missing_puinave_text_is_rejected():
    item = record()
    item["puinave"] = ""
    with pytest.raises(ValueError):
        build_multimedia_plan(item)


def test_batch_plans_five_resources_per_record():
    service = Spt0234Layer1Service()
    second = record()
    second["canonical_id"] = "LEX-002"
    second["puinave"] = "WAI"
    result = service.plan_batch([record(), second])
    assert result["records_processed"] == 2
    assert result["resource_plans"] == 10


def test_batch_never_enables_paid_api():
    result = Spt0234Layer1Service().plan_batch([record()])
    assert result["paid_api_allowed"] is False
    assert result["automatic_external_calls"] is False


def test_layer1_points_to_layer2():
    result = build_multimedia_plan(record()).to_dict()
    assert result["next_component"] == "SPT-023.4-CAPA-2"
