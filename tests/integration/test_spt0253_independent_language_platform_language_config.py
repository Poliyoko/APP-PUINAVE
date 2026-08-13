from sgoda.integration.spt0253 import *

def ref(): return reference_puinave_model()
def test_01(): assert DEFAULT_REFERENCE_SUPPORT==("es","en","it","pt")
def test_02(): assert normalize_code(" EN ")=="en"
def test_03(): assert build_language_descriptor("pui","Puinave","native")["role"]=="native"
def test_04(): assert build_language_descriptor("es","EspaÃ±ol","support")["code"]=="es"
def test_05(): assert validate_platform_language_model(ref())["valid"]
def test_06(): assert validate_platform_language_model(ref())["native_language_count"]==1
def test_07(): assert validate_platform_language_model(ref())["support_language_count"]==4
def test_08(): assert validate_platform_language_model(ref())["support_language_codes"]==["es","en","it","pt"]
def test_09(): assert ref()["output_selection"]["mode"]=="user_selectable"
def test_10(): assert ref()["navigation_language"]["configurable"] is True
def test_11(): assert ref()["translation_targets"]["configurable"] is True
def test_12(): assert ref()["definition_languages"]["configurable"] is True
def test_13(): assert ref()["example_languages"]["configurable"] is True
def test_14(): assert ref()["audio_languages"]["configurable"] is True
def test_15():
    x=ref(); x["support_languages"].append({"code":"pui","name":"Puinave","role":"support"})
    assert not validate_platform_language_model(x)["valid"]
def test_16():
    x=ref(); x["support_languages"].append({"code":"es","name":"EspaÃ±ol duplicado","role":"support"})
    assert "support_4_duplicate_code" in validate_platform_language_model(x)["errors"]
def test_17():
    x=ref(); x["support_languages_hardcoded"]=True
    assert "support_languages_must_not_be_hardcoded" in validate_platform_language_model(x)["errors"]
def test_18():
    x=ref(); x["independent_platform"]=False
    assert "platform_must_be_independent" in validate_platform_language_model(x)["errors"]
def test_19():
    cfg,res=build_independent_platform("sgoda-kurripaco","SGODA-KURRIPACO",{"code":"kpc","name":"Kurripaco"},[{"code":"es","name":"EspaÃ±ol"},{"code":"en","name":"English"}])
    assert res["valid"]
def test_20():
    cfg,res=build_independent_platform("sgoda-x","SGODA-X",{"code":"x","name":"Lengua X"},[])
    assert res["valid"] and res["support_language_count"]==0
def test_21():
    cfg,res=build_independent_platform("","SGODA-X",{"code":"x","name":"Lengua X"},[])
    assert not res["valid"]
def test_22():
    cfg,res=build_independent_platform("sgoda-x","",{"code":"x","name":"Lengua X"},[])
    assert not res["valid"]
def test_23():
    try: build_language_descriptor("","","native"); assert False
    except ValueError as e: assert str(e)=="language_code_required"
def test_24():
    try: build_language_descriptor("x","X","other"); assert False
    except ValueError as e: assert str(e)=="language_role_invalid"
