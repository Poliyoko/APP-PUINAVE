from sgoda.integration.spt0256 import *
def ref(): return reference_puinave_identity()
def test_01(): assert validate_platform_identity(ref())["valid"]
def test_02(): assert ref()["platform_id"]=="sgoda-puinave"
def test_03(): assert ref()["native_language"]["code"]=="pui"
def test_04(): assert ref()["community"]["community_id"]=="puinave"
def test_05(): assert ref()["branding"]["configurable_per_platform"] is True
def test_06(): assert ref()["institutional_texts"]["configurable_per_platform"] is True
def test_07(): assert ref()["cultural_metadata"]["configurable_per_platform"] is True
def test_08(): assert ref()["presentation"]["configurable_per_platform"] is True
def test_09(): assert ref()["sgoda_core_embeds_identity_values"] is False
def test_10():
    x=ref(); x["branding"]["configurable_per_platform"]=False
    assert "branding_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_11():
    x=ref(); x["community"]["name"]=""
    assert "community_name_required" in validate_platform_identity(x)["errors"]
def test_12():
    x=ref(); x["instance_specific"]=False
    assert "identity_must_be_instance_specific" in validate_platform_identity(x)["errors"]
def test_13():
    x=ref(); x["sgoda_core_embeds_identity_values"]=True
    assert "sgoda_core_must_not_embed_identity_values" in validate_platform_identity(x)["errors"]
def test_14():
    cfg,res=build_platform_identity("sgoda-kurripaco","SGODA-KURRIPACO","kurripaco","Pueblo Kurripaco","kpc","Kurripaco")
    assert res["valid"]
def test_15():
    cfg,res=build_platform_identity("","","x","Pueblo X","x","Lengua X")
    assert not res["valid"]
def test_16():
    x=ref(); x["presentation"]["configurable_per_platform"]=False
    assert "presentation_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_17():
    x=ref(); x["institutional_texts"]["configurable_per_platform"]=False
    assert "institutional_texts_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_18():
    x=ref(); x["cultural_metadata"]["configurable_per_platform"]=False
    assert "cultural_metadata_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_19(): assert identity_fingerprint(ref())==identity_fingerprint(ref())
def test_20():
    x=ref(); y=ref(); y["platform_name"]="OTHER"
    assert identity_fingerprint(x)!=identity_fingerprint(y)
def test_21(): assert ref()["presentation"]["show_native_language_first"] is True
def test_22(): assert ref()["institutional_texts"]["slogan"].startswith("TecnologÃ­a")
def test_23(): assert normalize_code(" PUI ")=="pui"
def test_24(): assert ref()["branding"]["theme"]["configurable"] is True
