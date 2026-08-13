from sgoda.integration.spt0252 import *

def ref(): return reference_puinave_contract()
def test_01(): assert PUINAVE_SUPPORT==("es","en","it","pt")
def test_02(): assert validate_native_language({"code":"pui","name":"Puinave"})["valid"]
def test_03(): assert not validate_native_language({})["valid"]
def test_04(): assert validate_support_languages(ref()["support_languages"])["valid"]
def test_05(): assert validate_platform_contract(ref())["valid"]
def test_06(): assert sgoda_core_contract()["one_native_language_per_platform"] is True
def test_07(): assert sgoda_core_contract()["support_languages_configurable"] is True
def test_08(): assert "bible_url" in sgoda_core_contract()["must_not_embed"]
def test_09(): assert "hardcoded_support_languages" in sgoda_core_contract()["must_not_embed"]
def test_10(): assert ref()["native_language"]["code"]=="pui"
def test_11(): assert [x["code"] for x in ref()["support_languages"]]==["es","en","it","pt"]
def test_12(): assert ref()["rlb"]["instance_specific"] is True
def test_13(): assert ref()["resources"]["configurable_per_platform"] is True
def test_14(): assert ref()["resources"]["bible"]["url_configurable"] is True
def test_15(): assert ref()["branding"]["configurable_per_platform"] is True
def test_16():
    x=ref(); x["support_languages"].append({"code":"pui","name":"Puinave"})
    assert not validate_platform_contract(x)["valid"]
def test_17():
    x=ref(); x["rlb"]["instance_specific"]=False
    assert "rlb_must_be_instance_specific" in validate_platform_contract(x)["errors"]
def test_18():
    x=ref(); x["resources"]["configurable_per_platform"]=False
    assert "resources_must_be_configurable_per_platform" in validate_platform_contract(x)["errors"]
def test_19():
    x=ref(); x["branding"]["configurable_per_platform"]=False
    assert "branding_must_be_configurable_per_platform" in validate_platform_contract(x)["errors"]
def test_20():
    x=ref(); x["support_languages"].append({"code":"es","name":"EspaÃ±ol 2"})
    assert "support_4_duplicate_code" in validate_platform_contract(x)["errors"]
