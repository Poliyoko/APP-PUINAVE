import json
from pathlib import Path
from .registry import WordRegistry
from .detector import IntelligentWordDetector
from .events import build_events,append_events
class Spt0231Service:
    def __init__(self,root):
        self.root=Path(root); self.runtime=self.root/"artifacts"/"runtime"/"spt0231"
    def detect_file(self,source):
        batch=IntelligentWordDetector(WordRegistry(self.runtime/"word-registry.json")).detect_file(Path(source))
        batch["events_written"]=append_events(self.runtime/"events.jsonl",build_events(batch))
        batch["pipeline_contract"]={"semantic":"SPT-023.2","category":"SPT-023.3","image":"SPT-023.4","audio_puinave":"SPT-023.5","audio_es":"SPT-023.5","audio_en":"SPT-023.5","audio_it":"SPT-023.5","fld_oda":"SPT-023.6"}
        self.runtime.mkdir(parents=True,exist_ok=True); (self.runtime/"last-detection.json").write_text(json.dumps(batch,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")
        return batch