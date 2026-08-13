from sgoda.integration.spt0259 import *

def ref():
    return reference_kurripaco_materialization_spec()

def test_01():
    assert validate_materialization_spec(ref())["valid"]

def test_02():
    assert normalize_instance_id("SGODA KURRIPACO") == "sgoda-kurripaco"

def test_03():
    assert validate_materialization_spec(ref())["native_language"] == "kpc"

def test_04():
    assert validate_materialization_spec(ref())["support_language_codes"] == ["es", "en"]

def test_05():
    assert build_materialization_package(ref())["valid"]

def test_06():
    assert build_materialization_package(ref())["manifest"]["shared_core_reference"] is True

def test_07():
    assert build_materialization_package(ref())["manifest"]["core_duplicated"] is False

def test_08():
    assert build_materialization_package(ref())["manifest"]["auto_deployed"] is False

def test_09():
    assert build_materialization_package(ref())["manifest"]["production_changed"] is False

def test_10():
    assert build_materialization_package(ref())["files"]["instance/rlb.json"]["records"] == []

def test_11():
    assert build_materialization_package(ref())["files"]["instance/rlb.json"]["bootstrap_state"] == "EMPTY_READY"

def test_12():
    assert build_materialization_package(ref())["files"]["instance/rollback-manifest.json"]["rollback_supported"] is True

def test_13():
    assert build_materialization_package(ref())["files"]["instance/rollback-manifest.json"]["destructive_cleanup_required"] is False

def test_14():
    value = ref()
    value["governance"]["shared_core_reference"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_15():
    value = ref()
    value["governance"]["duplicate_core"] = True
    assert not validate_materialization_spec(value)["valid"]

def test_16():
    value = ref()
    value["governance"]["auto_deploy"] = True
    assert not validate_materialization_spec(value)["valid"]

def test_17():
    value = ref()
    value["governance"]["production_change"] = True
    assert not validate_materialization_spec(value)["valid"]

def test_18():
    value = ref()
    value["support_languages"].append({"code": "kpc", "name": "Kurripaco"})
    assert not validate_materialization_spec(value)["valid"]

def test_19():
    value = ref()
    value["support_languages"].append({"code": "es", "name": "Duplicado"})
    assert not validate_materialization_spec(value)["valid"]

def test_20():
    value = ref()
    value["identity"]["instance_specific"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_21():
    value = ref()
    value["resources"]["instance_specific"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_22():
    value = ref()
    value["rlb"]["instance_specific"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_23():
    package = build_materialization_package(ref())
    assert package["manifest"]["materialization_contract"] == "SGODA_INSTANCE_PACKAGE_V1"

def test_24():
    package = build_materialization_package(ref())
    assert "instance/package-manifest.json" in package["files"]

def test_25():
    package = build_materialization_package(ref())
    assert len(package["manifest"]["file_hashes"]) == 6

def test_26():
    package = build_materialization_package(ref())
    assert package_fingerprint(package) == package_fingerprint(package)

def test_27():
    first = build_materialization_package(ref())
    second = build_materialization_package(ref())
    second["files"]["instance/platform.json"]["platform_name"] = "OTHER"
    assert package_fingerprint(first) != package_fingerprint(second)

def test_28():
    assert build_materialization_package(ref())["platform_id"] == "sgoda-kurripaco"

def test_29():
    package = build_materialization_package(ref())
    assert package["files"]["instance/platform.json"]["sgoda_core"]["embedded_copy"] is False

def test_30():
    package = build_materialization_package(ref())
    assert package["files"]["instance/governance.json"]["auto_deploy"] is False
