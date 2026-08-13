from sgoda.integration.spt0257 import *

def ref():
    return reference_puinave_bootstrap_spec()

def test_01():
    assert validate_bootstrap_spec(ref())["valid"]

def test_02():
    assert normalize_platform_id("SGODA KURRIPACO") == "sgoda-kurripaco"

def test_03():
    assert validate_bootstrap_spec(ref())["native_language"] == "pui"

def test_04():
    assert validate_bootstrap_spec(ref())["support_language_codes"] == ["es", "en", "it", "pt"]

def test_05():
    assert build_bootstrap_bundle(ref())["valid"]

def test_06():
    assert build_bootstrap_bundle(ref())["manifest"]["shared_core_reference"] is True

def test_07():
    assert build_bootstrap_bundle(ref())["manifest"]["core_copy_created"] is False

def test_08():
    assert build_bootstrap_bundle(ref())["manifest"]["production_deployed"] is False

def test_09():
    assert build_bootstrap_bundle(ref())["bundle"]["rlb.json"]["records"] == []

def test_10():
    assert build_bootstrap_bundle(ref())["bundle"]["rlb.json"]["bootstrap_state"] == "EMPTY_READY"

def test_11():
    value = ref()
    value["support_languages"].append({"code": "pui", "name": "Puinave"})
    assert not validate_bootstrap_spec(value)["valid"]

def test_12():
    value = ref()
    value["support_languages"].append({"code": "es", "name": "Duplicado"})
    assert not validate_bootstrap_spec(value)["valid"]

def test_13():
    value = ref()
    value["sgoda_core_mode"] = "embedded_copy"
    assert "sgoda_core_mode_must_be_shared_reference" in validate_bootstrap_spec(value)["errors"]

def test_14():
    value = ref()
    value["rlb"]["instance_specific"] = False
    assert "rlb_instance_specific_required" in validate_bootstrap_spec(value)["errors"]

def test_15():
    value = ref()
    value["resources"]["instance_specific"] = False
    assert "resources_instance_specific_required" in validate_bootstrap_spec(value)["errors"]

def test_16():
    value = ref()
    value["identity"]["instance_specific"] = False
    assert "identity_instance_specific_required" in validate_bootstrap_spec(value)["errors"]

def test_17():
    value = ref()
    value["platform_id"] = "bad"
    assert "platform_id_invalid" in validate_bootstrap_spec(value)["errors"]

def test_18():
    value = ref()
    value["platform_id"] = "sgoda-kurripaco"
    value["platform_name"] = "SGODA-KURRIPACO"
    value["community"] = {
        "community_id": "kurripaco",
        "name": "Pueblo Kurripaco",
    }
    value["native_language"] = {
        "code": "kpc",
        "name": "Kurripaco",
    }
    result = build_bootstrap_bundle(value)
    assert result["valid"]
    assert result["manifest"]["platform_id"] == "sgoda-kurripaco"

def test_19():
    value = ref()
    value["platform_id"] = "sgoda-x"
    value["platform_name"] = "SGODA-X"
    value["community"] = {"community_id": "x", "name": "Pueblo X"}
    value["native_language"] = {"code": "x", "name": "Lengua X"}
    value["support_languages"] = []
    assert build_bootstrap_bundle(value)["valid"]

def test_20():
    bundle = build_bootstrap_bundle(ref())["bundle"]
    assert bundle_fingerprint(bundle) == bundle_fingerprint(bundle)

def test_21():
    first = build_bootstrap_bundle(ref())["bundle"]
    second = build_bootstrap_bundle(ref())["bundle"]
    second["platform.json"]["platform_name"] = "OTHER"
    assert bundle_fingerprint(first) != bundle_fingerprint(second)

def test_22():
    assert set(build_bootstrap_bundle(ref())["bundle"]) == {
        "platform.json",
        "rlb.json",
        "resources.json",
        "identity.json",
        "bootstrap-manifest.json",
    }

def test_23():
    assert build_bootstrap_bundle(ref())["bundle"]["platform.json"]["sgoda_core"]["embedded_copy"] is False

def test_24():
    assert build_bootstrap_bundle(ref())["bundle"]["identity.json"]["instance_specific"] is True

def test_25():
    assert build_bootstrap_bundle(ref())["bundle"]["resources.json"]["instance_specific"] is True

def test_26():
    assert build_bootstrap_bundle(ref())["manifest"]["bootstrap_contract"] == "SGODA_LANGUAGE_INSTANCE_V1"
