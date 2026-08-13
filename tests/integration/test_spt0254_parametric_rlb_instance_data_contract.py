from sgoda.integration.spt0254 import *

SUP=("es","en","it","pt")
def ref(): return reference_puinave_lexeme()

def test_01(): assert len(REQUIRED_LEXEME_KEYS)==8
def test_02(): assert normalize_code(" PT ")=="pt"
def test_03(): assert validate_lexeme(ref(),"pui",SUP)["valid"]
def test_04():
    x=ref(); x["native_language"]="kpc"
    assert "native_language_mismatch" in validate_lexeme(x,"pui",SUP)["errors"]
def test_05():
    x=ref(); x["native_form"]=""
    assert "native_form_required" in validate_lexeme(x,"pui",SUP)["errors"]
def test_06():
    x=ref(); x["meanings"]["fr"]={"text":"x"}
    assert "meaning_language_not_enabled:fr" in validate_lexeme(x,"pui",SUP)["errors"]
def test_07():
    x=ref(); x["meanings"]["es"]={"text":""}
    assert "meaning_es_text_empty" in validate_lexeme(x,"pui",SUP)["errors"]
def test_08():
    x=ref(); x["pronunciation"]=[]
    assert "pronunciation_not_object" in validate_lexeme(x,"pui",SUP)["errors"]
def test_09():
    x=ref(); x["audio"]=[]
    assert "audio_not_object" in validate_lexeme(x,"pui",SUP)["errors"]
def test_10():
    x=ref(); x["images"]={}
    assert "images_not_list" in validate_lexeme(x,"pui",SUP)["errors"]
def test_11():
    x=ref(); x["metadata"]=[]
    assert "metadata_not_object" in validate_lexeme(x,"pui",SUP)["errors"]
def test_12():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["instance_specific"] is True
def test_13():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["sgoda_core_contains_lexical_data"] is False
def test_14():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["support_languages"]==["es","en","it","pt"]
def test_15():
    c=build_repository_contract("x","x",["x","es","es"])
    assert c["support_languages"]==["es"]
def test_16():
    c=build_repository_contract("x","x",[])
    assert c["support_languages"]==[]
def test_17():
    assert build_repository_contract("x","x",[])["backward_compatibility_adapter_required"] is True
def test_18():
    assert build_repository_contract("x","x",[])["support_language_meanings_configurable"] is True
def test_19():
    assert content_fingerprint(ref())==content_fingerprint(ref())
def test_20():
    x=ref(); y=ref(); y["native_form"]="AMDA2"
    assert content_fingerprint(x)!=content_fingerprint(y)
def test_21():
    x=ref(); del x["metadata"]
    assert "missing_metadata" in validate_lexeme(x,"pui",SUP)["errors"]
def test_22():
    x=ref(); x["meanings"]={}
    assert validate_lexeme(x,"pui",SUP)["valid"]
def test_23():
    x=ref()
    assert set(x["meanings"])==set(SUP)
def test_24():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["supports_native_audio"] and c["supports_pronunciation"] and c["supports_images"]
