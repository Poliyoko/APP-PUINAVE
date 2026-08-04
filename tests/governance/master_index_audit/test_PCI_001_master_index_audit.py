
import json
from pathlib import Path
from sgoda.governance.master_index_audit import audit, broken_links, code_set, scan, write_outputs

def repo(tmp_path: Path):
    for p in ("src/example","tests/example","docs","config/example","releases/SPT-999-v1.0.0"): (tmp_path/p).mkdir(parents=True,exist_ok=True)
    (tmp_path/"src/example/__init__.py").write_text("",encoding="utf-8")
    (tmp_path/"tests/example/test_example.py").write_text("def test_ok(): assert True\n",encoding="utf-8")
    (tmp_path/"docs/example.md").write_text("# Ejemplo\n",encoding="utf-8")
    (tmp_path/"docs/00_INDICE_MAESTRO.md").write_text("# Índice\n[Ejemplo](example.md)\nSPT-999\n",encoding="utf-8")
    (tmp_path/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("# Registro\nSPT-999\n",encoding="utf-8")
    (tmp_path/"docs/00_ARQUITECTURA_MAESTRA.md").write_text("# Arquitectura\n",encoding="utf-8")
    d={"increment_code":"SPT-999","name":"Ejemplo","version":"1.0.0","status":"closed","source":["src/example"],"tests":["tests/example"],"documentation":["docs/example.md"]}
    (tmp_path/"config/example/SPT-999-component.json").write_text(json.dumps(d),encoding="utf-8")
    (tmp_path/"releases/SPT-999-v1.0.0/manifest.json").write_text('{"release_name":"SPT-999-v1.0.0"}',encoding="utf-8")
    return tmp_path

def test_codes(): assert code_set("PCI-001 SPT-018")=={"PCI-001","SPT-018"}
def test_scan(tmp_path): items,bad=scan(repo(tmp_path)); assert len(items)==1 and items[0]["code"]=="SPT-999" and bad==[]
def test_complete(tmp_path): r=audit(repo(tmp_path)); assert r["approved"] and r["components"][0]["completion_percent"]==100
def test_missing_master(tmp_path): root=repo(tmp_path); (root/"docs/00_INDICE_MAESTRO.md").unlink(); assert not audit(root)["approved"]
def test_invalid_json(tmp_path): root=repo(tmp_path); (root/"config/example/bad.json").write_text("{bad",encoding="utf-8"); assert not audit(root)["approved"]
def test_duplicate(tmp_path): root=repo(tmp_path); s=root/"config/example/SPT-999-component.json"; (root/"config/example/dup.json").write_text(s.read_text(),encoding="utf-8"); assert not audit(root)["approved"]
def test_registry_gap_warning(tmp_path): root=repo(tmp_path); (root/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("# Registro\n",encoding="utf-8"); r=audit(root); assert r["approved"] and r["metrics"]["warning_findings"]==1
def test_broken_link(tmp_path): root=repo(tmp_path); idx=root/"docs/00_INDICE_MAESTRO.md"; text="[F](missing.md)"; assert broken_links(root,idx,text)==[{"target":"missing.md","reason":"not_found"}]
def test_external_link(tmp_path): root=repo(tmp_path); idx=root/"docs/00_INDICE_MAESTRO.md"; assert broken_links(root,idx,"[W](https://example.com)")==[]
def test_reports(tmp_path): payload=audit(repo(tmp_path)); j,m,h=tmp_path/"a.json",tmp_path/"a.md",tmp_path/"a.html"; write_outputs(payload,j,m,h); assert j.is_file() and m.is_file() and h.is_file()
def test_metrics(tmp_path): m=audit(repo(tmp_path))["metrics"]; json.dumps(m); assert m["registry_coverage_percent"]==100
def test_unknown_registry(tmp_path): root=repo(tmp_path); (root/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("SPT-999\nSPT-998\n",encoding="utf-8"); r=audit(root); assert any(f["code"]=="REGISTRY_CODE_WITHOUT_DESCRIPTOR" for f in r["findings"])
