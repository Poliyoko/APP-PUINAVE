from sgoda.integration.spt0255 import *

def ref(): return reference_puinave_catalog()

def test_01(): assert "bible" in ALLOWED_RESOURCE_TYPES
def test_02(): assert normalize_code(" PT ")=="pt"
def test_03(): assert normalize_resource_type("Custom")=="custom"
def test_04(): assert validate_catalog(ref())["valid"]
def test_05(): assert validate_catalog(ref())["resource_count"]==1
def test_06(): assert validate_catalog(ref())["enabled_count"]==1
def test_07(): assert ref()["native_language"]=="pui"
def test_08(): assert ref()["support_languages"]==["es","en","it","pt"]
def test_09(): assert ref()["sgoda_core_embeds_resource_values"] is False
def test_10(): assert ref()["resources"][0]["platform_configurable"] is True
def test_11(): assert ref()["resources"][0]["url_configurable"] is True
def test_12():
    x=ref(); x["resources"][0]["platform_configurable"]=False
    assert not validate_catalog(x)["valid"]
def test_13():
    x=ref(); x["resources"][0]["url_configurable"]=False
    assert not validate_catalog(x)["valid"]
def test_14():
    x=ref(); x["resources"][0]["source"]["url"]=""
    assert not validate_catalog(x)["valid"]
def test_15():
    x=ref(); x["resources"][0]["language_scope"]="fr"
    assert not validate_catalog(x)["valid"]
def test_16():
    x=ref(); x["resources"].append(dict(x["resources"][0]))
    assert any("duplicate_resource_id" in e for e in validate_catalog(x)["errors"])
def test_17():
    r=build_resource("X","Historia","story","pui",True,"local","stories/x.md")
    assert r["source"]["mode"]=="local"
def test_18():
    r=build_resource("X","Sitio","website","es",True,"url","https://example.invalid")
    assert r["source"]["mode"]=="url"
def test_19():
    r=build_resource("B","Biblia","bible","pui",True,"url","https://example.invalid")
    assert r["url_configurable"] is True
def test_20():
    x=ref(); x["resources"][0]["enabled"]=False
    assert validate_catalog(x)["valid"] and validate_catalog(x)["enabled_count"]==0
def test_21():
    x=ref(); x["instance_specific"]=False
    assert "catalog_must_be_instance_specific" in validate_catalog(x)["errors"]
def test_22():
    x=ref(); x["sgoda_core_embeds_resource_values"]=True
    assert "sgoda_core_must_not_embed_resource_values" in validate_catalog(x)["errors"]
def test_23(): assert catalog_fingerprint(ref())==catalog_fingerprint(ref())
def test_24():
    x=ref(); y=ref(); y["resources"][0]["name"]="Otra Biblia"
    assert catalog_fingerprint(x)!=catalog_fingerprint(y)
