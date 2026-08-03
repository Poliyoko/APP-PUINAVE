import json,pytest
from pathlib import Path
from sgoda.puinave_knowledge_center.models import KnowledgeQuery,KnowledgeRecord
from sgoda.puinave_knowledge_center.service import PuinaveKnowledgeCenter
def test_health():
 p=PuinaveKnowledgeCenter().health(); assert p["component"]=="SPT-017" and p["native_ecosystem"] and p["mandatory_proprietary_dependencies"]==[]
def test_register_get():
 c=PuinaveKnowledgeCenter(); r=KnowledgeRecord("culture:1","Relato","oral_history","pui","Memoria","SPT-017"); c.register(r); assert c.get("culture:1")==r
def test_validation():
 with pytest.raises(ValueError): PuinaveKnowledgeCenter().register(KnowledgeRecord("","X","cultural_record","pui","","SPT-017"))
def test_dictionary_bridge():
 r=PuinaveKnowledgeCenter().ingest_dictionary_entry({"id":"AMDA","word":"AMDA","media_ids":["img"],"oda_ids":["oda"]}); assert r.source_component=="SPT-013B" and r.media_ids==("img",) and r.oda_ids==("oda",)
def test_analytics_bridge():
 r=PuinaveKnowledgeCenter().ingest_learning_insight({"id":"I1","summary":"refuerzo"}); assert r.record_type=="learning_insight" and r.source_component=="SPT-016"
def test_search_accents_case():
 c=PuinaveKnowledgeCenter(); c.ingest_cultural_record({"id":"1","title":"Tradición oral","summary":"Relato"}); x=c.search(KnowledgeQuery(text="tradicion")); assert x.total==1
def test_filters():
 c=PuinaveKnowledgeCenter(); c.ingest_cultural_record({"id":"1","title":"Relato","language":"pui","record_type":"oral_history"}); c.ingest_cultural_record({"id":"2","title":"Informe","language":"es","record_type":"report"}); x=c.search(KnowledgeQuery(language="pui",record_type="oral_history")); assert x.total==1
def test_persistence(tmp_path:Path):
 p=tmp_path/"k.json"; c=PuinaveKnowledgeCenter(p); c.ingest_dictionary_entry({"id":"AMDA","word":"AMDA"}); assert PuinaveKnowledgeCenter(p).get("lex:AMDA") is not None and json.loads(p.read_text(encoding="utf-8"))["schema"]=="SPT-017-knowledge-center-v1"
def test_provenance():
 r=PuinaveKnowledgeCenter().ingest_cultural_record({"id":"1","title":"Registro","actor":"Consejo","license":"autorizado"}); assert r.provenance["actor"]=="Consejo" and r.provenance["license"]=="autorizado"
def test_existing_engine():
 import sgoda.knowledge_engine as k; assert k is not None
def test_contracts():
 c=PuinaveKnowledgeCenter(); c.ingest_dictionary_entry({"id":"A","word":"A"}); c.ingest_learning_insight({"id":"B"}); assert c.health()["source_components"]==["SPT-013B","SPT-016"]
def test_json_ready():
 c=PuinaveKnowledgeCenter(); c.ingest_dictionary_entry({"id":"AMDA","word":"AMDA"}); json.dumps(c.search(KnowledgeQuery(text="AMDA")).to_dict(),ensure_ascii=False)