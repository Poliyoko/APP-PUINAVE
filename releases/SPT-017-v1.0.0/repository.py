from __future__ import annotations
import json
from pathlib import Path
from .models import KnowledgeRecord
class KnowledgeCenterRepository:
    def __init__(self,storage_path=None):
        self.path=Path(storage_path).resolve() if storage_path else None; self.records={}
        if self.path and self.path.is_file(): self.load()
    def upsert(self,r): self.records[r.record_id]=r; self.save(); return r
    def get(self,i): return self.records.get(i)
    def all(self): return tuple(self.records[k] for k in sorted(self.records))
    def save(self):
        if not self.path: return
        self.path.parent.mkdir(parents=True,exist_ok=True)
        self.path.write_text(json.dumps({"schema":"SPT-017-knowledge-center-v1","records":[r.to_dict() for r in self.all()]},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    def load(self):
        p=json.loads(self.path.read_text(encoding="utf-8-sig")); self.records={}
        for x in p.get("records",[]):
            r=KnowledgeRecord(record_id=str(x["record_id"]),title=str(x["title"]),record_type=str(x["record_type"]),language=str(x["language"]),summary=str(x.get("summary","")),source_component=str(x["source_component"]),cultural_domain=str(x.get("cultural_domain","general")),tags=tuple(x.get("tags",[])),related_ids=tuple(x.get("related_ids",[])),media_ids=tuple(x.get("media_ids",[])),oda_ids=tuple(x.get("oda_ids",[])),version=str(x.get("version","1.0.0")),status=str(x.get("status","active")),provenance=dict(x.get("provenance",{})))
            self.records[r.record_id]=r