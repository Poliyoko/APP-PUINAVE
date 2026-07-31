from __future__ import annotations
import json
from pathlib import Path
from .exceptions import EvidenceConflictError, EvidenceNotFoundError
from .models import EvidenceRecord

class EvidenceRegistry:
    def __init__(self,path:Path)->None: self.path=path
    def _load_raw(self)->dict:
        if not self.path.exists(): return {"schema":"sgoda.sems.registry/v1","records":[]}
        return json.loads(self.path.read_text(encoding="utf-8"))
    def _save_raw(self,data:dict)->None:
        self.path.parent.mkdir(parents=True,exist_ok=True)
        tmp=self.path.with_suffix(self.path.suffix+".tmp")
        tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        tmp.replace(self.path)
    def list(self)->list[EvidenceRecord]:
        return [EvidenceRecord.from_dict(i) for i in self._load_raw().get("records",[])]
    def get(self,evidence_id:str)->EvidenceRecord:
        for record in self.list():
            if record.evidence_id==evidence_id: return record
        raise EvidenceNotFoundError(f"No existe la evidencia: {evidence_id}")
    def add(self,record:EvidenceRecord)->EvidenceRecord:
        data=self._load_raw(); records=data.setdefault("records",[])
        if any(i.get("evidence_id")==record.evidence_id for i in records):
            raise EvidenceConflictError(f"Ya existe la evidencia: {record.evidence_id}")
        records.append(record.to_dict()); self._save_raw(data); return record
    def update(self,record:EvidenceRecord)->EvidenceRecord:
        data=self._load_raw(); records=data.setdefault("records",[])
        for idx,item in enumerate(records):
            if item.get("evidence_id")==record.evidence_id:
                records[idx]=record.to_dict(); self._save_raw(data); return record
        raise EvidenceNotFoundError(f"No existe la evidencia: {record.evidence_id}")
    def count(self)->int: return len(self.list())