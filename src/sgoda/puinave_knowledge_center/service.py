from .repository import KnowledgeCenterRepository
from .index import KnowledgeCenterIndex
from .integrations import KnowledgeIntegrationBridge
class PuinaveKnowledgeCenter:
    component_code="SPT-017"; version="1.0.0"
    def __init__(self,storage_path=None): self.repository=KnowledgeCenterRepository(storage_path); self.index=KnowledgeCenterIndex(); self.bridge=KnowledgeIntegrationBridge()
    def register(self,r):
        if not r.record_id.strip() or not r.title.strip() or not r.source_component.strip(): raise ValueError("record_id, title and source_component are required")
        return self.repository.upsert(r)
    def ingest_dictionary_entry(self,p): return self.register(self.bridge.from_dictionary_entry(p))
    def ingest_learning_insight(self,p): return self.register(self.bridge.from_learning_analytics(p))
    def ingest_cultural_record(self,p): return self.register(self.bridge.from_cultural_record(p))
    def search(self,q): return self.index.search(self.repository.all(),q)
    def get(self,i): return self.repository.get(i)
    def health(self):
        rs=self.repository.all(); return {"component":self.component_code,"version":self.version,"status":"operational","record_count":len(rs),"source_components":sorted({r.source_component for r in rs}),"native_ecosystem":True,"mandatory_proprietary_dependencies":[]}