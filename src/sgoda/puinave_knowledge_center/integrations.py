from .models import KnowledgeRecord
from .provenance import build_provenance
class KnowledgeIntegrationBridge:
    def from_dictionary_entry(self,p):
        i=str(p.get("id") or p.get("record_id") or p.get("word") or p.get("term")); t=str(p.get("word") or p.get("term") or p.get("title") or i)
        return KnowledgeRecord(f"lex:{i}",t,"lexical_entry",str(p.get("language","pui")),str(p.get("meaning") or p.get("definition") or p.get("summary") or ""),"SPT-013B",str(p.get("cultural_domain","language")),tuple(p.get("tags",[])),media_ids=tuple(p.get("media_ids",[])),oda_ids=tuple(p.get("oda_ids",[])),provenance=build_provenance("SPT-013B",i))
    def from_learning_analytics(self,p):
        i=str(p.get("id") or p.get("insight_id") or "learning-insight")
        return KnowledgeRecord(f"analytics:{i}",str(p.get("title") or "Hallazgo de aprendizaje"),"learning_insight",str(p.get("language","es")),str(p.get("summary","")),"SPT-016","education",tuple(p.get("tags",[])),provenance=build_provenance("SPT-016",i))
    def from_cultural_record(self,p):
        i=str(p.get("id") or p.get("record_id") or p.get("title")); src=str(p.get("source_component","SPT-017"))
        return KnowledgeRecord(f"culture:{i}",str(p.get("title",i)),str(p.get("record_type","cultural_record")),str(p.get("language","pui")),str(p.get("summary","")),src,str(p.get("cultural_domain","culture")),tuple(p.get("tags",[])),tuple(p.get("related_ids",[])),tuple(p.get("media_ids",[])),tuple(p.get("oda_ids",[])),provenance=build_provenance(src,i,str(p.get("actor","SGODA-PUINAVE")),str(p.get("license","institutional"))))