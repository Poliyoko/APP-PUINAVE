import csv,json
from pathlib import Path
KEYS=("puinave","palabra_puinave","palabra","native","word","termino")
def _word(row):
    low={str(k).strip().lower():v for k,v in row.items()}
    for k in KEYS:
        v=low.get(k)
        if v is not None and str(v).strip(): return str(v).strip()
    return ""
def load_records(path):
    path=Path(path); s=path.suffix.lower(); rows=[]
    if s==".json":
        data=json.loads(path.read_text(encoding="utf-8-sig"))
        if isinstance(data,dict): data=next((data[k] for k in ("words","palabras","records","data") if isinstance(data.get(k),list)),[data])
        rows=[x if isinstance(x,dict) else {"puinave":str(x)} for x in data]
    elif s==".csv":
        with path.open("r",encoding="utf-8-sig",newline="") as f: rows=list(csv.DictReader(f))
    elif s in (".xlsx",".xlsm"):
        try: import openpyxl
        except ImportError as e: raise RuntimeError("Excel requires openpyxl (free/open-source).") from e
        wb=openpyxl.load_workbook(str(path),read_only=True,data_only=True); ws=wb.active; it=ws.iter_rows(values_only=True)
        try: headers=[str(v).strip() if v is not None else f"column_{i+1}" for i,v in enumerate(next(it))]
        except StopIteration: return []
        rows=[{headers[i]:v for i,v in enumerate(vals) if i<len(headers)} for vals in it]
    else: raise ValueError("Unsupported source; use JSON, CSV, XLSX or XLSM.")
    out=[]
    for r in rows:
        d={str(k).strip():v for k,v in dict(r).items()}; d["_puinave"]=_word(d); out.append(d)
    return out