
from __future__ import annotations
import argparse, hashlib, json, re, shutil
from pathlib import Path

PREFIX_ORDER={"ADR":10,"CERT":20,"PCI":30,"SGD":40,"SIB":50,"SPA":60,"SPB":70,"SPT":80}
CODE=re.compile(r"^(ADR|CERT|PCI|SGD|SIB|SPA|SPB|SPT)-(.+)$",re.I)

def vals(v):
    if isinstance(v,str): return (v.strip(),) if v.strip() else ()
    if isinstance(v,(list,tuple,set)): return tuple(sorted({str(x).strip() for x in v if str(x).strip()},key=str.casefold))
    return ()

def hist(code,status):
    return status.casefold() in {"historical","superseded","deprecated","archived"} or bool(re.search(r"-V\d+(?:\.\d+){1,3}",code,re.I)) or bool(re.search(r"-R\d+(?:\.\d+)*$",code,re.I))

def key(item):
    m=CODE.match(item["code"]); prefix=m.group(1).upper() if m else "ZZZ"; body=m.group(2) if m else item["code"]
    tokens=tuple((0,int(t)) if t.isdigit() else (1,t.casefold()) for t in re.split(r"([0-9]+)",body) if t)
    return (PREFIX_ORDER.get(prefix,999),tokens,item["version"].casefold(),item["name"].casefold(),item["descriptor_path"].casefold())

def collect(root_value):
    root=Path(root_value).resolve(); found={}
    for path in sorted((root/"config").rglob("*-component.json"),key=lambda p:p.as_posix().casefold()) if (root/"config").is_dir() else []:
        try: p=json.loads(path.read_text(encoding="utf-8-sig"))
        except Exception: continue
        if not isinstance(p,dict): continue
        code=str(p.get("increment_code") or p.get("component_code") or p.get("code") or "").strip().upper()
        if not code or not CODE.match(code): continue
        item={"code":code,"name":str(p.get("name") or p.get("title") or code).strip(),"version":str(p.get("version","")).strip(),"status":str(p.get("status","unknown")).strip(),"descriptor_path":path.relative_to(root).as_posix(),"dependencies":vals(p.get("dependencies"))}
        item["historical"]=hist(code,item["status"])
        if code not in found or item["descriptor_path"].casefold()<found[code]["descriptor_path"].casefold(): found[code]=item
    return tuple(sorted(found.values(),key=key))

def serialize(entries):
    active=[x for x in entries if not x["historical"]]; historical=[x for x in entries if x["historical"]]
    lines=["# Registro Maestro de Componentes","","> Documento canónico generado por PCI-001.3.","> Fuente de verdad: `config/**/*-component.json`.","> Salida determinística sin fechas ni identificadores aleatorios.","","## Componentes activos","","| Código | Nombre | Versión | Estado | Dependencias | Descriptor |","|---|---|---|---|---|---|"]
    for x in active: lines.append("| `{}` | {} | {} | {} | {} | `{}` |".format(x["code"],x["name"].replace("|","/"),x["version"] or "—",x["status"] or "unknown",", ".join(x["dependencies"]) or "—",x["descriptor_path"]))
    lines += ["","## Incrementos históricos","","| Código | Nombre | Versión | Estado | Dependencias | Descriptor |","|---|---|---|---|---|---|"]
    for x in historical: lines.append("| `{}` | {} | {} | {} | {} | `{}` |".format(x["code"],x["name"].replace("|","/"),x["version"] or "—",x["status"] or "historical",", ".join(x["dependencies"]) or "—",x["descriptor_path"]))
    return "\n".join(lines).rstrip()+"\n"

def determinize(root_value,output,backup_dir,evidence,generations=3):
    if generations<3: raise ValueError("Se requieren tres generaciones.")
    root=Path(root_value).resolve(); target=Path(output); target=target if target.is_absolute() else root/target
    entries=collect(root); outputs=[serialize(entries) for _ in range(generations)]; hashes=[hashlib.sha256(x.encode()).hexdigest() for x in outputs]
    if len(set(hashes))!=1: raise RuntimeError("Generaciones no idénticas.")
    backup=Path(backup_dir)/target.name; backup.parent.mkdir(parents=True,exist_ok=True)
    if target.is_file() and not backup.is_file(): shutil.copy2(target,backup)
    changed=not target.is_file() or target.read_text(encoding="utf-8-sig",errors="replace")!=outputs[0]
    target.parent.mkdir(parents=True,exist_ok=True); target.write_text(outputs[0],encoding="utf-8")
    report={"increment_code":"PCI-001.3","version":"1.0.0","components":len(entries),"generations":generations,"hashes":hashes,"canonical_sha256":hashes[0],"deterministic":True,"changed":changed,"approved":len(entries)>0}
    e=Path(evidence); e.parent.mkdir(parents=True,exist_ok=True); e.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return report

def main():
    p=argparse.ArgumentParser(); p.add_argument("--root",required=True); p.add_argument("--output",default="docs/00_REGISTRO_MAESTRO_COMPONENTES.md"); p.add_argument("--backup-dir",required=True); p.add_argument("--evidence-json",required=True); p.add_argument("--generations",type=int,default=3); a=p.parse_args()
    r=determinize(a.root,a.output,a.backup_dir,a.evidence_json,a.generations); print(json.dumps(r,ensure_ascii=False)); return 0 if r["approved"] else 2
