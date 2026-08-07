
import json
from pathlib import Path
from sgoda.governance.registry_determinizer import collect,serialize,determinize

def repo(tmp_path):
    for p in ("config/a","config/b","docs"): (tmp_path/p).mkdir(parents=True,exist_ok=True)
    (tmp_path/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("# old\n",encoding="utf-8")
    (tmp_path/"config/a/SPT-010-component.json").write_text(json.dumps({"increment_code":"SPT-010","name":"Diez","version":"1.0.0","status":"closed","dependencies":["SGD-117","PCI-001"]}),encoding="utf-8")
    (tmp_path/"config/b/SPT-002-component.json").write_text(json.dumps({"increment_code":"SPT-002","name":"Dos","version":"1.0.0","status":"closed","dependencies":["PCI-001","SGD-117","PCI-001"]}),encoding="utf-8")
    (tmp_path/"config/b/SGD-114E-v1.0.7-component.json").write_text(json.dumps({"increment_code":"SGD-114E-v1.0.7","name":"Hist","version":"1.0.7","status":"historical"}),encoding="utf-8")
    (tmp_path/"config/a/SPT-010-policy.json").write_text('{"component":"SPT-010"}',encoding="utf-8")
    return tmp_path

def test_order(tmp_path): assert [x["code"] for x in collect(repo(tmp_path))]==["SGD-114E-V1.0.7","SPT-002","SPT-010"]
def test_dependencies(tmp_path): assert [x for x in collect(repo(tmp_path)) if x["code"]=="SPT-002"][0]["dependencies"]==("PCI-001","SGD-117")
def test_no_timestamp(tmp_path): assert "Generado:" not in serialize(collect(repo(tmp_path)))
def test_three_equal(tmp_path):
    e=collect(repo(tmp_path)); assert len({serialize(e) for _ in range(3)})==1
def test_write_and_backup(tmp_path):
    root=repo(tmp_path); r=determinize(root,"docs/00_REGISTRO_MAESTRO_COMPONENTES.md",tmp_path/"backup",tmp_path/"evidence.json",3); assert r["approved"] and len(set(r["hashes"]))==1 and (tmp_path/"backup/00_REGISTRO_MAESTRO_COMPONENTES.md").is_file()
def test_idempotent(tmp_path):
    root=repo(tmp_path); a=determinize(root,"docs/00_REGISTRO_MAESTRO_COMPONENTES.md",tmp_path/"backup",tmp_path/"e.json",3); b=determinize(root,"docs/00_REGISTRO_MAESTRO_COMPONENTES.md",tmp_path/"backup",tmp_path/"e.json",3); assert a["canonical_sha256"]==b["canonical_sha256"] and not b["changed"]
def test_policy_ignored(tmp_path): assert len(collect(repo(tmp_path)))==3
def test_sections(tmp_path):
    s=serialize(collect(repo(tmp_path))); assert "## Componentes activos" in s and "## Incrementos históricos" in s
