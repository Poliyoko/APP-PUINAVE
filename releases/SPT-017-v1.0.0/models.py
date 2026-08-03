from __future__ import annotations
from dataclasses import dataclass,asdict,field
from typing import Any
@dataclass(frozen=True,slots=True)
class KnowledgeRecord:
    record_id:str; title:str; record_type:str; language:str; summary:str; source_component:str
    cultural_domain:str="general"; tags:tuple[str,...]=(); related_ids:tuple[str,...]=(); media_ids:tuple[str,...]=(); oda_ids:tuple[str,...]=(); version:str="1.0.0"; status:str="active"; provenance:dict[str,Any]=field(default_factory=dict)
    def to_dict(self):
        p=asdict(self)
        for k in ("tags","related_ids","media_ids","oda_ids"): p[k]=list(p[k])
        return p
@dataclass(frozen=True,slots=True)
class KnowledgeQuery:
    text:str=""; language:str|None=None; record_type:str|None=None; cultural_domain:str|None=None; tags:tuple[str,...]=(); limit:int=20
@dataclass(frozen=True,slots=True)
class KnowledgeSearchResult:
    records:tuple[KnowledgeRecord,...]; total:int; query:KnowledgeQuery
    def to_dict(self): return {"records":[r.to_dict() for r in self.records],"total":self.total,"query":asdict(self.query)}