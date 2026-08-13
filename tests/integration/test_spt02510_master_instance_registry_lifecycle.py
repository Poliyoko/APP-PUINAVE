from sgoda.integration.spt02510 import *

def ref():
    return example_reference_record()

def test_01(): assert validate_registry_record(ref())["valid"]
def test_02(): assert validate_registry_record(ref())["native_language"] == "qaa"
def test_03(): assert validate_registry_record(ref())["support_languages"] == ["es","en","it","pt"]
def test_04(): assert build_master_registry([ref()])["valid"]
def test_05(): assert build_master_registry([ref()])["real_instances"] == 0
def test_06(): assert build_master_registry([ref()])["example_records"] == 1
def test_07(): assert build_master_registry([ref()])["registry_contract"] == "SGODA_MASTER_INSTANCE_REGISTRY_V1"
def test_08(): assert ref()["governance"]["example_only"] is True
def test_09(): assert ref()["governance"]["auto_deployed"] is False
def test_10(): assert ref()["governance"]["production_changed"] is False
def test_11(): assert ref()["governance"]["core_duplicated"] is False
def test_12(): assert ref()["governance"]["shared_core_reference"] is True
def test_13(): assert can_transition("DRAFT","VALIDATED")
def test_14(): assert can_transition("VALIDATED","MATERIALIZED")
def test_15(): assert can_transition("MATERIALIZED","REGISTERED")
def test_16(): assert not can_transition("MATERIALIZED","DRAFT")
def test_17(): assert can_transition("REGISTERED","SUSPENDED")
def test_18(): assert can_transition("SUSPENDED","REGISTERED")
def test_19(): assert can_transition("REGISTERED","RETIRED")
def test_20(): assert can_transition("RETIRED","ARCHIVED")
def test_21():
    x=ref(); x["package"]["version"]="v1"; assert not validate_registry_record(x)["valid"]
def test_22():
    x=ref(); x["package"]["sha256"]="bad"; assert not validate_registry_record(x)["valid"]
def test_23():
    x=ref(); x["support_languages"].append({"code":"qaa","name":"bad"}); assert not validate_registry_record(x)["valid"]
def test_24():
    x=ref(); x["support_languages"].append({"code":"es","name":"dup"}); assert not validate_registry_record(x)["valid"]
def test_25():
    x=ref(); x["governance"]["core_duplicated"]=True; assert not validate_registry_record(x)["valid"]
def test_26():
    x=ref(); x["governance"]["auto_deployed"]=True; assert not validate_registry_record(x)["valid"]
def test_27():
    x=ref(); x["governance"]["production_changed"]=True; assert not validate_registry_record(x)["valid"]
def test_28():
    x=ref(); x["lifecycle"]["state"]="UNKNOWN"; assert not validate_registry_record(x)["valid"]
def test_29(): assert len(record_fingerprint(ref())) == 64
def test_30():
    x=ref(); assert not build_master_registry([x,x])["valid"]
def test_31(): assert normalize_instance_id("SGODA Example Language") == "sgoda-example-language"
def test_32(): assert normalize_code("EN_us") == "en-us"
