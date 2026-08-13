from sgoda.integration.spt02511 import *

def template():
    return generic_template()

def profile():
    return generic_example_profile()

def test_01(): assert validate_template(template())["valid"]
def test_02(): assert validate_profile(profile())["valid"]
def test_03(): assert template_profile_compatible(template(), profile())["compatible"]
def test_04(): assert build_catalog([template()], [profile()])["valid"]
def test_05(): assert build_catalog([template()], [profile()])["real_instance_count"] == 0
def test_06(): assert build_catalog([template()], [profile()])["example_profile_count"] == 1
def test_07(): assert template()["native_language"]["mode"] == "CONFIGURABLE_EXACTLY_ONE"
def test_08(): assert template()["support_languages"]["mode"] == "CONFIGURABLE_0_TO_N"
def test_09(): assert template()["support_languages"]["hard_coded"] is False
def test_10(): assert profile()["governance"]["example_only"] is True
def test_11(): assert profile()["governance"]["auto_deploy"] is False
def test_12(): assert profile()["governance"]["production_change"] is False
def test_13(): assert template()["governance"]["shared_core_reference"] is True
def test_14(): assert template()["governance"]["duplicate_core"] is False
def test_15(): assert profile()["native_language"]["code"] == "qaa"
def test_16(): assert [x["code"] for x in profile()["support_languages"]] == ["es","en","it","pt"]
def test_17():
    x=template(); x["support_languages"]["hard_coded"]=True; assert not validate_template(x)["valid"]
def test_18():
    x=template(); x["governance"]["duplicate_core"]=True; assert not validate_template(x)["valid"]
def test_19():
    x=template(); x["governance"]["auto_deploy"]=True; assert not validate_template(x)["valid"]
def test_20():
    x=template(); x["governance"]["production_change"]=True; assert not validate_template(x)["valid"]
def test_21():
    x=profile(); x["support_languages"].append({"code":"qaa","name":"bad"}); assert not validate_profile(x)["valid"]
def test_22():
    x=profile(); x["support_languages"].append({"code":"es","name":"dup"}); assert not validate_profile(x)["valid"]
def test_23():
    x=profile(); x["template_id"]="other-template"; assert not template_profile_compatible(template(),x)["compatible"]
def test_24():
    x=profile(); x["governance"]["auto_deploy"]=True; assert not validate_profile(x)["valid"]
def test_25():
    x=profile(); x["governance"]["production_change"]=True; assert not validate_profile(x)["valid"]
def test_26(): assert len(fingerprint(template())) == 64
def test_27(): assert fingerprint(template()) == fingerprint(template())
def test_28():
    a=template(); b=template(); b["version"]="1.0.1"; assert fingerprint(a) != fingerprint(b)
def test_29():
    assert not build_catalog([template(),template()],[profile()])["valid"]
def test_30():
    assert build_catalog([template()],[profile()])["catalog_contract"] == "SGODA_INSTANCE_TEMPLATE_PROFILE_CATALOG_V1"
def test_31(): assert normalize_id("SGODA Language Platform") == "sgoda-language-platform"
def test_32(): assert normalize_code("EN_us") == "en-us"
def test_33(): assert template()["resources"]["bible_optional"] is True
def test_34(): assert template()["identity"]["configurable"] is True
