from sgoda.integration.spt0251 import *
def test_01(): assert SUPPORT_LANGUAGE_CODES==("es","en","it","pt")
def test_02(): assert audit([])["support_language_model"]["native_language_per_platform"]==1
def test_03(): assert audit([])["support_language_model"]["support_languages_configurable"] is True
def test_04(): assert audit([])["support_language_model"]["hardcoded_output_languages_allowed"] is False
def test_05(): assert audit([])["replicability_principles"]["independent_platforms"] is True
def test_06(): assert audit([])["replicability_principles"]["shared_sgoda_core"] is True
def test_07(): assert audit([])["replicability_principles"]["rlb_instance_specific"] is True
def test_08(): assert audit([])["replicability_principles"]["bible_resource_configurable_per_platform"] is True
def test_09(): assert audit([])["replicability_principles"]["support_languages_configurable_per_platform"] is True
def test_10(): assert classify("src/sgoda/core/service.py","")["category"]==CATEGORY_CORE
def test_11(): assert classify("data/puinave/rlb.json","")["category"]==CATEGORY_INSTANCE
def test_12(): assert classify("src/sgoda/integration/x.py","Puinave")["category"]==CATEGORY_SHARED
def test_13(): assert classify("README.txt","generic")["category"]==CATEGORY_REVIEW
def test_14(): assert classify("resources/bible.json","")["category"]==CATEGORY_INSTANCE
def test_15(): assert "CONFIGURABLE_SURFACE" in classify("config/integration/x.json","Puinave")["reasons"]
def test_16(): assert sum(audit([{"path":"src/sgoda/core.py","text":""}])["counts"].values())==1
def test_17(): assert len(audit([{"path":"x","text":""}])["findings"])==1
def test_18(): assert audit([])["support_language_model"]["example_support_languages"]==["es","en","it","pt"]
def test_19(): assert audit([])["replicability_principles"]["one_native_language_per_platform"] is True
def test_20(): assert set(audit([])["counts"])=={CATEGORY_CORE,CATEGORY_INSTANCE,CATEGORY_SHARED,CATEGORY_REVIEW}
def test_21(): assert classify("config/x.json",{"language":"Puinave"})["category"]==CATEGORY_SHARED
def test_22(): assert classify("data/x.json",{"resource":"Biblia"})["category"]==CATEGORY_INSTANCE
def test_23(): assert classify("data/x.txt",["Puinave","es"])["category"]==CATEGORY_INSTANCE
def test_24(): assert classify("README.txt",None)["category"]==CATEGORY_REVIEW
