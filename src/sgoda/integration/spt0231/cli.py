import argparse,json
from pathlib import Path
from .service import Spt0231Service
def main():
    p=argparse.ArgumentParser(); p.add_argument("--project-root",required=True); p.add_argument("--source",required=True); a=p.parse_args()
    print(json.dumps(Spt0231Service(Path(a.project_root)).detect_file(Path(a.source)),ensure_ascii=False,indent=2,sort_keys=True)); return 0
if __name__=="__main__": raise SystemExit(main())