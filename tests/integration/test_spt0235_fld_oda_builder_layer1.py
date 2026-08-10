import copy

import pytest

from sgoda.integration.spt0235.fld import build_fld
from sgoda.integration.spt0235.models import parse_ready_for_fld_oda
from sgoda.integration.spt0235.oda import build_oda
from sgoda.integration.spt0235.service import Spt0235Layer1Service


RESOURCE_TYPES = (
    ("image", None, "image/png"),
    ("audio_puinave", "pui", "audio/wav"),
    ("audio_es", "es-CO", "audio/wav"),
    ("audio_en", "en-US", "audio/wav"),
    ("audio_it", "it-IT", "audio/wav"),
)


def handoff():
    resources = []
    for index, (resource_type, language, media_type) in enumerate(RESOURCE_TYPES, start=1):
        resources.append(
            {
                "resource_id": f"MM-{index}",
                "resource_type": resource_type,
                "output_path": f"media/LEX-001/{resource_type}.bin",
                "sha256": f"{index}" * 64,
                "language": language,
                "reviewer": "reviewer-01",
                "validation": {
                    "valid": True,
                    "media_type": media_type,
                },
            }
        )

    return {
        "component": "SPT-023.4",
        "layer": "3",
        "status": "READY_FOR_FLD_ODA",
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "category_id": "CAT-NATURE",
        "multimedia_manifest_sha256": "A" * 64,
        "resources": resources,
        "paid_api_used": False,
        "next_component": "SPT-023.5",
    }


def translations():
    return {
        "es": "palabra ejemplo",
        "en": "example word",
        "it": "parola esempio",
    }


def test_ready_input_is_parsed():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    assert source.lexical_id == "LEX-001"
    assert len(source.resources) == 5


def test_non_ready_input_is_rejected():
    payload = handoff()
    payload["status"] = "MULTIMEDIA_REVIEW_REQUIRED"
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_missing_lexical_id_is_rejected():
    payload = handoff()
    payload["lexical_id"] = ""
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_missing_puinave_is_rejected():
    payload = handoff()
    payload["puinave"] = ""
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_missing_manifest_sha_is_rejected():
    payload = handoff()
    payload["multimedia_manifest_sha256"] = ""
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_exactly_five_resources_are_required():
    payload = handoff()
    payload["resources"] = payload["resources"][:-1]
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_duplicate_resource_type_is_rejected():
    payload = handoff()
    payload["resources"][4]["resource_type"] = "image"
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_fld_contains_lexical_identity():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    assert fld["object_type"] == "FLD"
    assert fld["lexical_id"] == "LEX-001"
    assert fld["puinave"] == "AMDA"


def test_fld_contains_all_translations():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    assert fld["translations"]["es"] == "palabra ejemplo"
    assert fld["translations"]["en"] == "example word"
    assert fld["translations"]["it"] == "parola esempio"


def test_fld_references_five_multimedia_resources():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    assert len(fld["resources"]) == 5


def test_fld_hash_is_deterministic():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    one = build_fld(source)
    two = build_fld(source)
    assert one["fld_sha256"] == two["fld_sha256"]


def test_oda_requires_fld():
    with pytest.raises(ValueError):
        build_oda({"object_type": "OTHER"})


def test_oda_contains_source_fld_hash():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    oda = build_oda(fld)
    assert oda["source_fld_sha256"] == fld["fld_sha256"]


def test_oda_contains_learning_object():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    oda = build_oda(build_fld(source))
    assert oda["object_type"] == "ODA"
    assert oda["learning_object"]["term"] == "AMDA"


def test_oda_hash_is_deterministic():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    one = build_oda(fld)
    two = build_oda(fld)
    assert one["oda_sha256"] == two["oda_sha256"]


def test_service_builds_fld_and_oda():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["status"] == "FLD_ODA_BUILT"
    assert result["fld"]["object_type"] == "FLD"
    assert result["oda"]["object_type"] == "ODA"


def test_service_preserves_multimedia_manifest_traceability():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["traceability"]["source_multimedia_manifest_sha256"] == "A" * 64


def test_service_points_to_layer2():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["next_component"] == "SPT-023.5-CAPA-2"


def test_batch_builds_two_records():
    second = copy.deepcopy(handoff())
    second["lexical_id"] = "LEX-002"
    second["puinave"] = "WAI"
    for item in second["resources"]:
        item["resource_id"] = "SECOND-" + item["resource_id"]

    result = Spt0235Layer1Service().build_batch(
        [handoff(), second],
        translations_by_lexical_id={
            "LEX-001": translations(),
            "LEX-002": {"es": "dos", "en": "two", "it": "due"},
        },
    )
    assert result["records_processed"] == 2
    assert result["fld_built"] == 2
    assert result["oda_built"] == 2


def test_fld_and_oda_hashes_are_different():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["fld"]["fld_sha256"] != result["oda"]["oda_sha256"]
