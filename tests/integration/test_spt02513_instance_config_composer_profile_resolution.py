from sgoda.integration.spt02513 import *
def t(): return generic_template()
def b(): return generic_base_profile()
def e(): return generic_extension_profile()
def o(): return generic_overlay()
def test_01(): assert validate_profile(b())["valid"]
def test_02(): assert resolve_profiles([b(),e()])["valid"]
def test_03(): assert compose(t(),[b(),e()],o())["valid"]
def test_04(): assert compose(t(),[b(),e()],o())["native_language"]=="qaa"
def test_05(): assert compose(t(),[b(),e()],o())["support_languages"]==["es","en","it","pt"]
def test_06(): assert len(compose(t(),[b(),e()],o())["sha256"])==64
def test_07():
    x=e();x["native_language"]={"code":"zzz"};assert not resolve_profiles([b(),x])["valid"]
def test_08():
    x=e();x["template_id"]="other";assert not resolve_profiles([b(),x])["valid"]
def test_09():
    x=o();x["platform"]["native_language"]={"code":"zzz"};assert not compose(t(),[b(),e()],x)["valid"]
def test_10():
    x=o();x["governance"]["core_duplicated"]=True;assert not compose(t(),[b(),e()],x)["valid"]
def test_11():
    x=o();x["governance"]["auto_deployed"]=True;assert not compose(t(),[b(),e()],x)["valid"]
def test_12():
    x=o();x["governance"]["production_changed"]=True;assert not compose(t(),[b(),e()],x)["valid"]
def test_13():
    x=t();x["support_languages"]["hard_coded"]=True;assert not compose(x,[b(),e()],o())["valid"]
def test_14(): assert t()["native_language"]["mode"]=="CONFIGURABLE_EXACTLY_ONE"
def test_15(): assert t()["support_languages"]["mode"]=="CONFIGURABLE_0_TO_N"
def test_16(): assert b()["governance"]["example_only"] is True
def test_17():
    r=resolve_profiles([b(),e()])["resolved"];assert r["identity_profile"]["community"]=="Example Community"
def test_18():
    r=resolve_profiles([b(),e()])["resolved"];assert r["identity_profile"]["theme"]=="configurable"
def test_19(): assert not resolve_profiles([])["valid"]
def test_20():
    x=o();x["platform"]["support_languages"]=[{"code":"qaa"}];assert not compose(t(),[b(),e()],x)["valid"]
def test_21():
    x=o();x["platform"]["support_languages"]=[{"code":"es"},{"code":"es"}];assert not compose(t(),[b(),e()],x)["valid"]
def test_22(): assert compose(t(),[b(),e()],o())["configuration"]["resources"]["bible"]["enabled"] is False
def test_23(): assert compose(t(),[b(),e()],o())["configuration"]["governance"]["example_only"] is True
def test_24(): assert compose(t(),[b(),e()],o())["sha256"]==compose(t(),[b(),e()],o())["sha256"]
