import json
from datetime import datetime,timezone
def build_events(batch):
    out=[]
    for w in batch["words"]:
        if w["status"]!="NEW": continue
        out.append({"event_type":"SPT0231.NEW_PUINAVE_WORD","occurred_at":datetime.now(timezone.utc).isoformat(),"component":"SPT-023.1","payload":{
          "puinave":w["puinave"],"normalized_puinave":w["normalized_puinave"],"lexical_hash":w["lexical_hash"],"source":w["source"],"source_index":w["source_index"],
          "next_stages":["SPT-023.2_SEMANTIC_ANALYSIS","SPT-023.3_CATEGORY_ASSIGNMENT","SPT-023.4_IMAGE_GENERATION","SPT-023.5_AUDIO_PUINAVE","SPT-023.5_AUDIO_ES","SPT-023.5_AUDIO_EN","SPT-023.5_AUDIO_IT","SPT-023.6_FLD_ODA"],"requires_human_validation":True}})
    return out
def append_events(path,events):
    path.parent.mkdir(parents=True,exist_ok=True); n=0
    with path.open("a",encoding="utf-8") as f:
        for e in events: f.write(json.dumps(e,ensure_ascii=False,sort_keys=True)+"\n"); n+=1
    return n