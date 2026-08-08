import hashlib,unicodedata
from .sources import load_records

def normalize_puinave(value): return " ".join(unicodedata.normalize("NFC",str(value or "")).strip().split()).casefold()
def lexical_hash(n): return hashlib.sha256(("PUINAVE|"+n).encode("utf-8")).hexdigest()
class IntelligentWordDetector:
    def __init__(self,registry): self.registry=registry
    def detect_records(self,records,source):
        words=[]; seen=set(); c={"NEW":0,"EXISTING":0,"DUPLICATE":0,"INVALID":0}
        for i,r in enumerate(records,1):
            original=str(r.get("_puinave","") or "").strip(); n=normalize_puinave(original); h=lexical_hash(n) if n else ""
            if not n: status="INVALID"
            elif h in seen: status="DUPLICATE"
            elif self.registry.contains(n,h): status="EXISTING"
            else: status="NEW"; seen.add(h); self.registry.add(n,h)
            c[status]+=1
            words.append({"source_index":i,"puinave":original,"normalized_puinave":n,"lexical_hash":h,"status":status,"source":source,
              "category_status":"PENDING","image_status":"PENDING","audio_puinave_status":"PENDING_NATIVE_RECORDING",
              "audio_es_status":"PENDING","audio_en_status":"PENDING","audio_it_status":"PENDING","fld_status":"PENDING","oda_status":"PENDING",
              "validation_required":True,"metadata":{str(k):v for k,v in r.items() if k!="_puinave"}})
        self.registry.save()
        bh=hashlib.sha256("\n".join(sorted(x["lexical_hash"] for x in words if x["lexical_hash"])).encode("utf-8")).hexdigest()
        return {"source":source,"records_seen":len(records),"new_words":c["NEW"],"existing_words":c["EXISTING"],"duplicates":c["DUPLICATE"],"invalid":c["INVALID"],"batch_hash":bh,"words":words}
    def detect_file(self,path): return self.detect_records(load_records(path),str(path))