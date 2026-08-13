from sgoda.integration.spt0258 import *

def bundle():
    return simulate_kurripaco_bundle()

def test_01():
    assert validate_bundle(bundle())["valid"]

def test_02():
    assert validate_bundle(bundle())["native_language"] == "kpc"

def test_03():
    assert validate_bundle(bundle())["support_languages"] == ["es", "en"]

def test_04():
    assert compatibility_gate(bundle())["all_pass"]

def test_05():
    assert compatibility_gate(bundle())["language_contract"]

def test_06():
    assert compatibility_gate(bundle())["rlb_contract"]

def test_07():
    assert compatibility_gate(bundle())["resource_contract"]

def test_08():
    assert compatibility_gate(bundle())["identity_contract"]

def test_09():
    assert compatibility_gate(bundle())["sgoda_core_compatibility"]

def test_10():
    assert compatibility_gate(bundle())["bootstrap_manifest"]

def test_11():
    assert nondestructive_replication_trial()["deployed"] is False

def test_12():
    assert nondestructive_replication_trial()["production_changed"] is False

def test_13():
    assert nondestructive_replication_trial()["sgoda_puinave_modified"] is False

def test_14():
    assert nondestructive_replication_trial()["core_duplicated"] is False

def test_15():
    assert len(nondestructive_replication_trial()["sha256"]) == 64

def test_16():
    value = bundle()
    value["platform.json"]["sgoda_core"]["embedded_copy"] = True
    assert not validate_bundle(value)["valid"]

def test_17():
    value = bundle()
    value["bootstrap-manifest.json"]["production_deployed"] = True
    assert not validate_bundle(value)["valid"]

def test_18():
    value = bundle()
    value["rlb.json"]["native_language"] = "pui"
    assert not validate_bundle(value)["valid"]

def test_19():
    value = bundle()
    value["resources.json"]["instance_specific"] = False
    assert not validate_bundle(value)["valid"]

def test_20():
    value = bundle()
    value["identity.json"]["platform_id"] = "sgoda-other"
    assert not validate_bundle(value)["valid"]

def test_21():
    value = bundle()
    value["platform.json"]["support_languages"].append({"code": "kpc", "name": "Kurripaco"})
    assert not validate_bundle(value)["valid"]

def test_22():
    first = bundle_sha256(bundle())
    second = bundle_sha256(bundle())
    assert first == second

def test_23():
    value = bundle()
    first = bundle_sha256(value)
    value["identity.json"]["platform_name"] = "OTHER"
    assert bundle_sha256(value) != first

def test_24():
    value = bundle()
    del value["resources.json"]
    assert not validate_bundle(value)["valid"]

def test_25():
    assert bundle()["rlb.json"]["records"] == []

def test_26():
    assert bundle()["bootstrap-manifest.json"]["shared_core_reference"] is True

def test_27():
    assert bundle()["bootstrap-manifest.json"]["core_copy_created"] is False

def test_28():
    assert bundle()["bootstrap-manifest.json"]["production_deployed"] is False
