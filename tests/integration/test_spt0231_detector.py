import json
from sgoda.integration.spt0231.detector import IntelligentWordDetector,normalize_puinave,lexical_hash
from sgoda.integration.spt0231.registry import WordRegistry
from sgoda.integration.spt0231.events import build_events
from sgoda.integration.spt0231.service import Spt0231Service

def test_normalize(): assert normalize_puinave("  AMDA  ")=="amda"
def test_hash_stable(): assert lexical_hash("amda")==lexical_hash("amda")
def test_new(tmp_path):
 d=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")); b=d.detect_records([{"_puinave":"AMDA"}],"mem"); assert b["new_words"]==1 and b["words"][0]["status"]=="NEW"
def test_duplicate_same_batch(tmp_path):
 d=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")); b=d.detect_records([{"_puinave":"AMDA"},{"_puinave":" amda "}],"mem"); assert b["new_words"]==1 and b["duplicates"]==1
def test_existing_next_batch(tmp_path):
 p=tmp_path/"r.json";IntelligentWordDetector(WordRegistry(p)).detect_records([{"_puinave":"AMDA"}],"a");b=IntelligentWordDetector(WordRegistry(p)).detect_records([{"_puinave":"AMDA"}],"b");assert b["existing_words"]==1
def test_invalid(tmp_path):
 b=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")).detect_records([{"_puinave":""}],"m");assert b["invalid"]==1
def test_events_include_category_image_audio_it(tmp_path):
 b=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")).detect_records([{"_puinave":"AMDA"}],"m");s=build_events(b)[0]["payload"]["next_stages"];assert "SPT-023.3_CATEGORY_ASSIGNMENT" in s and "SPT-023.4_IMAGE_GENERATION" in s and "SPT-023.5_AUDIO_IT" in s
def test_json_detection(tmp_path):
 p=tmp_path/"w.json";p.write_text(json.dumps([{"puinave":"AMDA"},{"puinave":"OTRA"}]),encoding="utf-8");r=Spt0231Service(tmp_path).detect_file(p);assert r["records_seen"]==2 and r["events_written"]==2
def test_registry_persists(tmp_path):
 p=tmp_path/"r.json";r=WordRegistry(p);r.add("amda",lexical_hash("amda"));r.save();assert WordRegistry(p).contains("amda",lexical_hash("amda"))
def test_pending_contract(tmp_path):
 w=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")).detect_records([{"_puinave":"AMDA"}],"m")["words"][0];assert w["category_status"]=="PENDING" and w["image_status"]=="PENDING" and w["audio_es_status"]=="PENDING" and w["audio_en_status"]=="PENDING" and w["audio_it_status"]=="PENDING"