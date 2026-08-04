
import json
from pathlib import Path
from sgoda.governance.master_index_audit import (
    audit, broken_links, code_set, extract_codes, intelligent_audit,
    scan, scan_components, write_auxiliary, write_outputs
)

def repo(tmp_path: Path):
    for p in ("src/example","tests/example","docs","config/example","releases/SPT-999-v1.0.0","artifacts","scripts"):
        (tmp_path/p).mkdir(parents=True,exist_ok=True)
    (tmp_path/"src/example/__init__.py").write_text("",encoding="utf-8")
    (tmp_path/"tests/example/test_example.py").write_text("def test_ok(): assert True\n",encoding="utf-8")
    (tmp_path/"docs/example.md").write_text("# SPT-999 — Ejemplo\n",encoding="utf-8")
    (tmp_path/"docs/00_INDICE_MAESTRO.md").write_text("| Código | Nombre |\n|---|---|\n| `SPT-999` | Ejemplo |\n[Ejemplo](example.md)\n",encoding="utf-8")
    (tmp_path/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("| Código | Estado |\n|---|---|\n| `SPT-999` | closed |\n",encoding="utf-8")
    (tmp_path/"docs/00_ARQUITECTURA_MAESTRA.md").write_text("# Arquitectura\n",encoding="utf-8")
    d={"increment_code":"SPT-999","name":"Ejemplo","version":"1.0.0","status":"closed","source":["src/example"],"tests":["tests/example"],"documentation":["docs/example.md"]}
    (tmp_path/"config/example/SPT-999-component.json").write_text(json.dumps(d),encoding="utf-8")
    (tmp_path/"config/example/SPT-999-policy.json").write_text('{"component":"SPT-999"}',encoding="utf-8")
    (tmp_path/"releases/SPT-999-v1.0.0/manifest.json").write_text('{"increment_code":"SPT-999","version":"1.0.0"}',encoding="utf-8")
    return tmp_path

def test_policy_not_component(tmp_path):
    c,b,i=scan_components(repo(tmp_path)); assert len(c)==1 and b==[] and i==["config/example/SPT-999-policy.json"]
def test_filename_fragments_rejected():
    assert extract_codes("`SPT-017`\nSPT-017-Arquitectura.md\nSPT-017-component.json\nSPT-017-v1.0.0\n")=={"SPT-017"}
def test_structural_codes():
    assert extract_codes("| `PCI-001.1` | Auditor |\n## SPT-018 — IA\n")=={"PCI-001.1","SPT-018"}
def test_complete_approved(tmp_path):
    r=intelligent_audit(repo(tmp_path)); assert r["approved"] and r["metrics"]["critical_findings"]==0 and r["components"][0]["completion_percent"]==100
def test_release_no_double_version(tmp_path):
    assert intelligent_audit(repo(tmp_path))["components"][0]["release"]["directory"]=="SPT-999-v1.0.0"
def test_historical_classification(tmp_path):
    root=repo(tmp_path); d={"increment_code":"SGD-114E-v1.0.7","version":"1.0.7","status":"historical"}; (root/"config/example/SGD-114E-v1.0.7-component.json").write_text(json.dumps(d),encoding="utf-8"); items=intelligent_audit(root)["components"]; assert [x for x in items if x["code"]=="SGD-114E-V1.0.7"][0]["historical_increment"]
def test_true_duplicate_critical(tmp_path):
    root=repo(tmp_path); s=root/"config/example/SPT-999-component.json"; (root/"config/example/SPT-999-copy-component.json").write_text(s.read_text(),encoding="utf-8"); assert not intelligent_audit(root)["approved"]
def test_policy_not_duplicate(tmp_path):
    assert not any(f["code"]=="DUPLICATE_CANONICAL_DESCRIPTOR" for f in intelligent_audit(repo(tmp_path))["findings"])
def test_semantic(tmp_path):
    assert intelligent_audit(repo(tmp_path))["components"][0]["semantic"]["code_mentioned"]
def test_broken_link(tmp_path):
    root=repo(tmp_path); (root/"docs/00_INDICE_MAESTRO.md").write_text("[F](missing.md)",encoding="utf-8"); assert not intelligent_audit(root)["approved"]
def test_backward_compatibility(tmp_path):
    root=repo(tmp_path); assert audit(root)["approved"]; c,b=scan(root); assert len(c)==1 and b==[] and code_set("`SPT-999`")=={"SPT-999"}
def test_external_ignored(tmp_path):
    root=repo(tmp_path); idx=root/"docs/00_INDICE_MAESTRO.md"; assert broken_links(root,idx,"[W](https://example.com)")==[]
def test_outputs(tmp_path):
    payload=intelligent_audit(repo(tmp_path)); paths=[tmp_path/f"o/{n}" for n in ("a.json","a.md","a.html","m.json","t.json","p.json")]; write_outputs(payload,*paths[:3]); write_auxiliary(payload,*paths[3:]); assert all(p.is_file() for p in paths)
def test_graph(tmp_path):
    relations={e["relation"] for e in intelligent_audit(repo(tmp_path))["traceability_graph"]["edges"]}; assert {"implemented_by","verified_by","documented_by","released_as"}<=relations
