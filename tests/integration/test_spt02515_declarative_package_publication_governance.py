from sgoda.integration.spt02515 import *

def p(): return example_publication_package()
def r(): return example_materialization_record()

def test_01(): assert validate_publication_package(p())["valid"]
def test_02(): assert can_promote("DRAFT","VALIDATED")
def test_03(): assert can_promote("VALIDATED","APPROVED")
def test_04(): assert can_promote("APPROVED","PUBLISHED")
def test_05(): assert can_promote("PUBLISHED","RETIRED")
def test_06(): assert not can_promote("DRAFT","PUBLISHED")
def test_07(): assert build_promotion_record(p(),"APPROVED","PUBLISHED")["valid"]
def test_08(): assert build_promotion_record(p(),"APPROVED","PUBLISHED")["real_platform_deployed"] is False
def test_09(): assert build_promotion_record(p(),"APPROVED","PUBLISHED")["production_changed"] is False
def test_10(): assert build_materialization_registry([r()])["valid"]
def test_11(): assert build_materialization_registry([r()])["real_platform_count"]==0
def test_12(): assert build_materialization_registry([r()])["example_record_count"]==1
def test_13(): assert build_materialization_registry([r()])["registry_contract"]=="SGODA_MATERIALIZATION_REGISTRY_V1"
def test_14():
    x=p();x["governance"]["core_duplicated"]=True;assert not validate_publication_package(x)["valid"]
def test_15():
    x=p();x["governance"]["auto_deploy"]=True;assert not validate_publication_package(x)["valid"]
def test_16():
    x=p();x["governance"]["production_change"]=True;assert not validate_publication_package(x)["valid"]
def test_17():
    x=p();x["materialization_mode"]="REAL_DEPLOYMENT";assert not validate_publication_package(x)["valid"]
def test_18():
    x=p();x["configuration_sha256"]="bad";assert not validate_publication_package(x)["valid"]
def test_19():
    x=r();assert not build_materialization_registry([x,x])["valid"]
def test_20(): assert len(fingerprint(p()))==64
def test_21(): assert fingerprint(p())==fingerprint(p())
def test_22(): assert p()["governance"]["example_only"] is True
def test_23(): assert p()["governance"]["shared_core_reference"] is True
def test_24(): assert r()["real_platform"] is False
def test_25(): assert r()["auto_deployed"] is False
def test_26(): assert r()["production_changed"] is False
