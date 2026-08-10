import copy
import json

import pytest

from sgoda.integration.spt0235.layer2 import Spt0235Layer2Service
from sgoda.integration.spt0235.query import FldOdaQueryService
from sgoda.integration.spt0235.references import validate_object_references
from sgoda.integration.spt0235.registry import FldOdaRegistry


def build_result():
    resources = {}
    for index, resource_type in enumerate(
        ("image", "audio_puinave", "audio_es", "audio_en", "audio_it"),
        start=1,
    ):
        resources[resource_type] = {
            "resource_id": f"MM-{index}",
            "resource_type": resource_type,
            "output_path": f"media/LEX-001/{resource_type}.bin",
            "sha256": f"{index}" * 64,
        }

    fld = {
        "schema_version": "1.0.0",
        "object_type": "FLD",
        "component": "SPT-023.5",
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "category_id": "CAT-NATURE",
        "translations": {
            "es": "palabra ejemplo",
            "en": "example word",
            "it": "parola esempio",
        },
        "multimedia_manifest_sha256": "A" * 64,
        "resources": resources,
        "fld_sha256": "F" * 64,
    }
    oda = {
        "schema_version": "1.0.0",
        "object_type": "ODA",
        "component": "SPT-023.5",
        "lexical_id": "LEX-001",
        "title": "AMDA",
        "learning_object": {
            "term": "AMDA",
            "category_id": "CAT-NATURE",
            "translations": dict(fld["translations"]),
            "multimedia": dict(resources),
        },
        "source_fld_sha256": fld["fld_sha256"],
        "multimedia_manifest_sha256": fld["multimedia_manifest_sha256"],
        "oda_sha256": "O" * 64,
    }
    return {
        "component": "SPT-023.5",
        "layer": "1",
        "status": "FLD_ODA_BUILT",
        "lexical_id": "LEX-001",
        "fld": fld,
        "oda": oda,
    }


def test_reference_validation_accepts_valid_pair():
    result = build_result()
    validation = validate_object_references(result["fld"], result["oda"])
    assert validation["references_valid"] is True
    assert validation["resource_count"] == 5


def test_reference_validation_rejects_lexical_mismatch():
    result = build_result()
    result["oda"]["lexical_id"] = "LEX-X"
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_reference_validation_rejects_fld_hash_mismatch():
    result = build_result()
    result["oda"]["source_fld_sha256"] = "X"
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_reference_validation_rejects_manifest_mismatch():
    result = build_result()
    result["oda"]["multimedia_manifest_sha256"] = "X"
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_reference_validation_requires_five_resources():
    result = build_result()
    result["fld"]["resources"].pop("audio_it")
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_registry_persists_first_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    stored = registry.save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    assert stored["version"] == 1
    assert registry.get("LEX-001")["version"] == 1


def test_registry_increments_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    registry.save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    second = copy.deepcopy(result)
    second["fld"]["fld_sha256"] = "G" * 64
    second["oda"]["source_fld_sha256"] = "G" * 64
    second["oda"]["oda_sha256"] = "P" * 64
    stored = registry.save_entry(
        lexical_id="LEX-001",
        fld=second["fld"],
        oda=second["oda"],
    )
    assert stored["version"] == 2


def test_registry_can_retrieve_specific_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    registry.save_entry(lexical_id="LEX-001", fld=result["fld"], oda=result["oda"])
    second = copy.deepcopy(result)
    second["fld"]["fld_sha256"] = "G" * 64
    second["oda"]["source_fld_sha256"] = "G" * 64
    second["oda"]["oda_sha256"] = "P" * 64
    registry.save_entry(lexical_id="LEX-001", fld=second["fld"], oda=second["oda"])
    assert registry.get("LEX-001", version=1)["version"] == 1
    assert registry.get("LEX-001", version=2)["version"] == 2


def test_registry_returns_none_for_unknown_lexical_id(tmp_path):
    registry = FldOdaRegistry(tmp_path / "registry.json")
    assert registry.get("UNKNOWN") is None


def test_registry_detects_tampering(tmp_path):
    result = build_result()
    path = tmp_path / "registry.json"
    registry = FldOdaRegistry(path)
    registry.save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    data = json.loads(path.read_text(encoding="utf-8"))
    data["entries"]["LEX-001"]["versions"][0]["version_sha256"] = "BAD"
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValueError):
        registry.load()


def test_query_returns_latest_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    registry.save_entry(lexical_id="LEX-001", fld=result["fld"], oda=result["oda"])
    query = FldOdaQueryService(registry)
    found = query.by_lexical_id("LEX-001")
    assert found["version"] == 1
    assert found["fld"]["object_type"] == "FLD"
    assert found["oda"]["object_type"] == "ODA"


def test_query_returns_none_when_missing(tmp_path):
    query = FldOdaQueryService(FldOdaRegistry(tmp_path / "registry.json"))
    assert query.by_lexical_id("LEX-404") is None


def test_layer2_persists_valid_build_result(tmp_path):
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    result = service.persist(build_result())
    assert result["status"] == "FLD_ODA_PERSISTED"
    assert result["version"] == 1


def test_layer2_rejects_wrong_status(tmp_path):
    payload = build_result()
    payload["status"] = "OTHER"
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    with pytest.raises(ValueError):
        service.persist(payload)


def test_layer2_can_retrieve_after_persist(tmp_path):
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    service.persist(build_result())
    found = service.retrieve("LEX-001")
    assert found["lexical_id"] == "LEX-001"


def test_version_sha_is_deterministic_for_same_version_body(tmp_path):
    result = build_result()
    one = FldOdaRegistry(tmp_path / "one.json").save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    two = FldOdaRegistry(tmp_path / "two.json").save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    assert one["version_sha256"] == two["version_sha256"]


def test_registry_rejects_oda_not_referencing_fld(tmp_path):
    result = build_result()
    result["oda"]["source_fld_sha256"] = "X"
    registry = FldOdaRegistry(tmp_path / "registry.json")
    with pytest.raises(ValueError):
        registry.save_entry(
            lexical_id="LEX-001",
            fld=result["fld"],
            oda=result["oda"],
        )


def test_require_files_detects_missing_multimedia(tmp_path):
    result = build_result()
    with pytest.raises(ValueError):
        validate_object_references(
            result["fld"],
            result["oda"],
            require_files=True,
        )


def test_layer2_points_to_layer3(tmp_path):
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    result = service.persist(build_result())
    assert result["next_component"] == "SPT-023.5-CAPA-3"


def test_registry_file_is_valid_json(tmp_path):
    result = build_result()
    path = tmp_path / "registry.json"
    registry = FldOdaRegistry(path)
    registry.save_entry(lexical_id="LEX-001", fld=result["fld"], oda=result["oda"])
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["registry_type"] == "FLD_ODA_MASTER"
