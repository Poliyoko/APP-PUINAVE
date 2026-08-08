import json
from pathlib import Path
class WordRegistry:
    def __init__(self,path):
        self.path=Path(path); self.path.parent.mkdir(parents=True,exist_ok=True); self.words={}; self.hashes=set(); self._load()
    def _load(self):
        if not self.path.exists(): return
        data=json.loads(self.path.read_text(encoding="utf-8"))
        for x in data.get("words",[]):
            n=str(x.get("normalized_puinave","")).strip(); h=str(x.get("lexical_hash","")).strip()
            if n:self.words[n]=h
            if h:self.hashes.add(h)
    def contains(self,n,h=None): return n in self.words or (bool(h) and h in self.hashes)
    def add(self,n,h): self.words[n]=h; self.hashes.add(h)
    def save(self):
        payload={"schema":"spt0231.word-registry.v1","words":[{"normalized_puinave":n,"lexical_hash":h} for n,h in sorted(self.words.items())]}
        self.path.write_text(json.dumps(payload,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")