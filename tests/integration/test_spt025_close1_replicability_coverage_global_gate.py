from sgoda.integration.spt025close1 import *

def rows():
    return build_coverage(synthetic_paths())

def test_01_expected(): assert len(EXPECTED_COMPONENTS) == 16
def test_02_first(): assert EXPECTED_COMPONENTS[0] == "SPT-025.1"
def test_03_last(): assert EXPECTED_COMPONENTS[-1] == "SPT-025.16"
def test_04_coverage(): assert summarize_coverage(rows())["coverage_percent"] == 100.0
def test_05_complete(): assert summarize_coverage(rows())["complete"]
def test_06_code(): assert all(x["code"] for x in rows())
def test_07_tests(): assert all(x["tests"] for x in rows())
def test_08_config(): assert all(x["config"] for x in rows())
def test_09_docs(): assert all(x["docs"] for x in rows())
def test_10_evidence(): assert all(x["evidence"] for x in rows())
def test_11_exec(): assert all(x["executable"] for x in rows())
def test_12_repl(): assert validate_replicability_contract(reference_replicability_contract())["valid"]
def test_13_gate(): assert global_quality_gate(rows(),reference_replicability_contract(),"PASS")["pass"]
def test_14_prepare(): assert global_quality_gate(rows(),reference_replicability_contract(),"PASS")["institutional_closure_prepare"] == "APPROVED"
def test_15_component_1(): assert component_from_path("docs/SPT-025.1/test.md") == "SPT-025.1"
def test_16_component_16(): assert component_from_path("docs/SPT-025.16/test.md") == "SPT-025.16"
def test_17_component_none(): assert component_from_path("README.md") is None
def test_18_hash(): assert len(fingerprint({"x":1})) == 64
def test_19_no_hardcode():
    x=reference_replicability_contract(); x["hard_coded_support_languages"]=True
    assert not validate_replicability_contract(x)["valid"]
def test_20_one_native():
    x=reference_replicability_contract(); x["one_native_language_per_platform"]=False
    assert not validate_replicability_contract(x)["valid"]
def test_21_core_ref():
    x=reference_replicability_contract(); x["shared_core_reference"]=False
    assert not validate_replicability_contract(x)["valid"]
def test_22_core_dup():
    x=reference_replicability_contract(); x["core_duplicated"]=True
    assert not validate_replicability_contract(x)["valid"]
def test_23_real_deploy():
    x=reference_replicability_contract(); x["real_platform_deployed"]=True
    assert not validate_replicability_contract(x)["valid"]
def test_24_gate_fail():
    assert not global_quality_gate(rows(),reference_replicability_contract(),"FAIL")["pass"]
def test_25_missing():
    x=rows(); x[0]["present"]=False
    assert not summarize_coverage(x)["complete"]
def test_26_rlb():
    x=reference_replicability_contract(); x["rlb_instance_specific"]=False
    assert not validate_replicability_contract(x)["valid"]
def test_27_resources():
    x=reference_replicability_contract(); x["resources_instance_specific"]=False
    assert not validate_replicability_contract(x)["valid"]
def test_28_identity():
    x=reference_replicability_contract(); x["identity_instance_specific"]=False
    assert not validate_replicability_contract(x)["valid"]
def test_29_statuses(): assert len(FINAL_GATE_STATUSES) == 16
def test_30_supports(): assert reference_replicability_contract()["support_languages"] == "0..N_CONFIGURABLE"
