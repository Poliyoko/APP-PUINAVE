import argparse,json
from pathlib import Path
from .models import KnowledgeQuery
from .service import PuinaveKnowledgeCenter
def main():
    p=argparse.ArgumentParser(); p.add_argument("--storage",required=True); p.add_argument("--operation",choices=("health","search","demo"),required=True); p.add_argument("--query",default=""); p.add_argument("--output-json",required=True); a=p.parse_args(); c=PuinaveKnowledgeCenter(a.storage)
    if a.operation=="health": out=c.health()
    elif a.operation=="search": out=c.search(KnowledgeQuery(text=a.query)).to_dict()
    else:
        c.ingest_dictionary_entry({"id":"AMDA","word":"AMDA","meaning":"Entrada léxica demostrativa.","language":"pui","tags":["diccionario","demostración"]}); out=c.search(KnowledgeQuery(text="AMDA")).to_dict()
    t=Path(a.output_json); t.parent.mkdir(parents=True,exist_ok=True); t.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8"); print(json.dumps(out,ensure_ascii=False)); return 0
if __name__=="__main__": raise SystemExit(main())