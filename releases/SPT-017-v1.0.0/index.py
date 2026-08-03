from __future__ import annotations
import re,unicodedata
from .models import KnowledgeSearchResult
def norm(v):
    t=unicodedata.normalize("NFKD",str(v or "")); return re.sub(r"\s+"," ","".join(c for c in t if not unicodedata.combining(c)).casefold()).strip()
class KnowledgeCenterIndex:
    def search(self,records,q):
        n=norm(q.text); req={norm(x) for x in q.tags}; ranked=[]
        for r in records:
            if r.status!="active" or (q.language and r.language!=q.language) or (q.record_type and r.record_type!=q.record_type) or (q.cultural_domain and r.cultural_domain!=q.cultural_domain): continue
            tags={norm(x) for x in r.tags}
            if req and not req.issubset(tags): continue
            h=norm(" ".join((r.title,r.summary,r.record_type,r.cultural_domain," ".join(r.tags))))
            if n and n not in h: continue
            s=(100 if n and n==norm(r.title) else 0)+(50 if n and n in norm(r.title) else 0)+(20 if n and n in norm(r.summary) else 0)+(10 if n and n in tags else 0)
            ranked.append((-s,norm(r.title),r))
        ranked.sort(key=lambda x:(x[0],x[1])); rows=tuple(x[2] for x in ranked[:max(1,q.limit)])
        return KnowledgeSearchResult(rows,len(ranked),q)