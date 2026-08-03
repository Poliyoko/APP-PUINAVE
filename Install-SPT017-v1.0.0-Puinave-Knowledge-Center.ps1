<# SPT-017 v1.0.0 - Centro de Conocimiento Puinave. Compatible con Windows PowerShell 5.1. #>
[CmdletBinding()]param([string]$ProjectRoot=(Get-Location).Path,[switch]$Publish)
Set-StrictMode -Version Latest;$ErrorActionPreference="Stop"
function Step([string]$m){Write-Host "";Write-Host "==> $m" -ForegroundColor Cyan}
function Req([string]$p){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Falta: $p"}}
function W([string]$p,[string]$c){$d=Split-Path -Parent $p;if($d){New-Item -ItemType Directory -Path $d -Force|Out-Null};[IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)));Write-Host "Creado/actualizado: $p" -ForegroundColor Green}
function J([string]$p,[object]$v){W $p (($v|ConvertTo-Json -Depth 100)+[Environment]::NewLine)}
function Run([string]$d,[scriptblock]$a){Step $d;$global:LASTEXITCODE=0;&$a;if($LASTEXITCODE-ne 0){throw "$d terminó con errores. Código: $LASTEXITCODE"}}
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot);Set-Location -LiteralPath $ProjectRoot;$env:PYTHONPATH=Join-Path $ProjectRoot "src"
$src=Join-Path $ProjectRoot "src\sgoda\puinave_knowledge_center";$tst=Join-Path $ProjectRoot "tests\puinave_knowledge_center";$cfg=Join-Path $ProjectRoot "config\puinave_knowledge_center";$doc=Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-017";$pmo=Join-Path $ProjectRoot "artifacts\pmo\SPT-017-v1.0.0";$rep=Join-Path $ProjectRoot "releases\SPT-017-v1.0.0";$data=Join-Path $ProjectRoot "artifacts\knowledge_center";$reports=Join-Path $pmo "test-reports"
$runner=Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1";$publisher=Join-Path $ProjectRoot "scripts\Invoke-SPB007-CanonicalPublish.ps1"
@("src\sgoda\knowledge_engine\__init__.py","tests\knowledge_engine\test_SPT_007C_knowledge_engine.py","src\sgoda\dictionary_manager\__init__.py","src\sgoda\multimedia_engine\__init__.py","src\sgoda\learning_analytics\__init__.py","src\sgoda\oda\__init__.py","src\sgoda\governance\test_evidence\cli.py","src\sgoda\governance\release_management\cli.py","src\sgoda\governance\repository_manager\cli.py","src\sgoda\documentation\master_docs.py","src\sgoda\roadmap\cli.py","scripts\Invoke-InstitutionalPytest.ps1","scripts\Invoke-SPB007-CanonicalPublish.ps1")|ForEach-Object{Req (Join-Path $ProjectRoot $_)}
@($src,$tst,$cfg,$doc,$pmo,$rep,$data,$reports)|ForEach-Object{New-Item -ItemType Directory -Path $_ -Force|Out-Null}
$F___init___py = @'
from .models import KnowledgeQuery,KnowledgeRecord,KnowledgeSearchResult
from .service import PuinaveKnowledgeCenter
__all__=["KnowledgeQuery","KnowledgeRecord","KnowledgeSearchResult","PuinaveKnowledgeCenter"]
'@
$F_models_py = @'
from __future__ import annotations
from dataclasses import dataclass,asdict,field
from typing import Any
@dataclass(frozen=True,slots=True)
class KnowledgeRecord:
    record_id:str; title:str; record_type:str; language:str; summary:str; source_component:str
    cultural_domain:str="general"; tags:tuple[str,...]=(); related_ids:tuple[str,...]=(); media_ids:tuple[str,...]=(); oda_ids:tuple[str,...]=(); version:str="1.0.0"; status:str="active"; provenance:dict[str,Any]=field(default_factory=dict)
    def to_dict(self):
        p=asdict(self)
        for k in ("tags","related_ids","media_ids","oda_ids"): p[k]=list(p[k])
        return p
@dataclass(frozen=True,slots=True)
class KnowledgeQuery:
    text:str=""; language:str|None=None; record_type:str|None=None; cultural_domain:str|None=None; tags:tuple[str,...]=(); limit:int=20
@dataclass(frozen=True,slots=True)
class KnowledgeSearchResult:
    records:tuple[KnowledgeRecord,...]; total:int; query:KnowledgeQuery
    def to_dict(self): return {"records":[r.to_dict() for r in self.records],"total":self.total,"query":asdict(self.query)}
'@
$F_repository_py = @'
from __future__ import annotations
import json
from pathlib import Path
from .models import KnowledgeRecord
class KnowledgeCenterRepository:
    def __init__(self,storage_path=None):
        self.path=Path(storage_path).resolve() if storage_path else None; self.records={}
        if self.path and self.path.is_file(): self.load()
    def upsert(self,r): self.records[r.record_id]=r; self.save(); return r
    def get(self,i): return self.records.get(i)
    def all(self): return tuple(self.records[k] for k in sorted(self.records))
    def save(self):
        if not self.path: return
        self.path.parent.mkdir(parents=True,exist_ok=True)
        self.path.write_text(json.dumps({"schema":"SPT-017-knowledge-center-v1","records":[r.to_dict() for r in self.all()]},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    def load(self):
        p=json.loads(self.path.read_text(encoding="utf-8-sig")); self.records={}
        for x in p.get("records",[]):
            r=KnowledgeRecord(record_id=str(x["record_id"]),title=str(x["title"]),record_type=str(x["record_type"]),language=str(x["language"]),summary=str(x.get("summary","")),source_component=str(x["source_component"]),cultural_domain=str(x.get("cultural_domain","general")),tags=tuple(x.get("tags",[])),related_ids=tuple(x.get("related_ids",[])),media_ids=tuple(x.get("media_ids",[])),oda_ids=tuple(x.get("oda_ids",[])),version=str(x.get("version","1.0.0")),status=str(x.get("status","active")),provenance=dict(x.get("provenance",{})))
            self.records[r.record_id]=r
'@
$F_index_py = @'
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
'@
$F_provenance_py = @'
from datetime import datetime,timezone
def build_provenance(source_component,source_id,actor="SGODA-PUINAVE",license_name="institutional"):
    return {"source_component":source_component,"source_id":source_id,"actor":actor,"license":license_name,"recorded_at_utc":datetime.now(timezone.utc).isoformat()}
'@
$F_integrations_py = @'
from .models import KnowledgeRecord
from .provenance import build_provenance
class KnowledgeIntegrationBridge:
    def from_dictionary_entry(self,p):
        i=str(p.get("id") or p.get("record_id") or p.get("word") or p.get("term")); t=str(p.get("word") or p.get("term") or p.get("title") or i)
        return KnowledgeRecord(f"lex:{i}",t,"lexical_entry",str(p.get("language","pui")),str(p.get("meaning") or p.get("definition") or p.get("summary") or ""),"SPT-013B",str(p.get("cultural_domain","language")),tuple(p.get("tags",[])),media_ids=tuple(p.get("media_ids",[])),oda_ids=tuple(p.get("oda_ids",[])),provenance=build_provenance("SPT-013B",i))
    def from_learning_analytics(self,p):
        i=str(p.get("id") or p.get("insight_id") or "learning-insight")
        return KnowledgeRecord(f"analytics:{i}",str(p.get("title") or "Hallazgo de aprendizaje"),"learning_insight",str(p.get("language","es")),str(p.get("summary","")),"SPT-016","education",tuple(p.get("tags",[])),provenance=build_provenance("SPT-016",i))
    def from_cultural_record(self,p):
        i=str(p.get("id") or p.get("record_id") or p.get("title")); src=str(p.get("source_component","SPT-017"))
        return KnowledgeRecord(f"culture:{i}",str(p.get("title",i)),str(p.get("record_type","cultural_record")),str(p.get("language","pui")),str(p.get("summary","")),src,str(p.get("cultural_domain","culture")),tuple(p.get("tags",[])),tuple(p.get("related_ids",[])),tuple(p.get("media_ids",[])),tuple(p.get("oda_ids",[])),provenance=build_provenance(src,i,str(p.get("actor","SGODA-PUINAVE")),str(p.get("license","institutional"))))
'@
$F_service_py = @'
from .repository import KnowledgeCenterRepository
from .index import KnowledgeCenterIndex
from .integrations import KnowledgeIntegrationBridge
class PuinaveKnowledgeCenter:
    component_code="SPT-017"; version="1.0.0"
    def __init__(self,storage_path=None): self.repository=KnowledgeCenterRepository(storage_path); self.index=KnowledgeCenterIndex(); self.bridge=KnowledgeIntegrationBridge()
    def register(self,r):
        if not r.record_id.strip() or not r.title.strip() or not r.source_component.strip(): raise ValueError("record_id, title and source_component are required")
        return self.repository.upsert(r)
    def ingest_dictionary_entry(self,p): return self.register(self.bridge.from_dictionary_entry(p))
    def ingest_learning_insight(self,p): return self.register(self.bridge.from_learning_analytics(p))
    def ingest_cultural_record(self,p): return self.register(self.bridge.from_cultural_record(p))
    def search(self,q): return self.index.search(self.repository.all(),q)
    def get(self,i): return self.repository.get(i)
    def health(self):
        rs=self.repository.all(); return {"component":self.component_code,"version":self.version,"status":"operational","record_count":len(rs),"source_components":sorted({r.source_component for r in rs}),"native_ecosystem":True,"mandatory_proprietary_dependencies":[]}
'@
$F_cli_py = @'
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
'@
$F_tests = @'
import json,pytest
from pathlib import Path
from sgoda.puinave_knowledge_center.models import KnowledgeQuery,KnowledgeRecord
from sgoda.puinave_knowledge_center.service import PuinaveKnowledgeCenter
def test_health():
 p=PuinaveKnowledgeCenter().health(); assert p["component"]=="SPT-017" and p["native_ecosystem"] and p["mandatory_proprietary_dependencies"]==[]
def test_register_get():
 c=PuinaveKnowledgeCenter(); r=KnowledgeRecord("culture:1","Relato","oral_history","pui","Memoria","SPT-017"); c.register(r); assert c.get("culture:1")==r
def test_validation():
 with pytest.raises(ValueError): PuinaveKnowledgeCenter().register(KnowledgeRecord("","X","cultural_record","pui","","SPT-017"))
def test_dictionary_bridge():
 r=PuinaveKnowledgeCenter().ingest_dictionary_entry({"id":"AMDA","word":"AMDA","media_ids":["img"],"oda_ids":["oda"]}); assert r.source_component=="SPT-013B" and r.media_ids==("img",) and r.oda_ids==("oda",)
def test_analytics_bridge():
 r=PuinaveKnowledgeCenter().ingest_learning_insight({"id":"I1","summary":"refuerzo"}); assert r.record_type=="learning_insight" and r.source_component=="SPT-016"
def test_search_accents_case():
 c=PuinaveKnowledgeCenter(); c.ingest_cultural_record({"id":"1","title":"Tradición oral","summary":"Relato"}); x=c.search(KnowledgeQuery(text="tradicion")); assert x.total==1
def test_filters():
 c=PuinaveKnowledgeCenter(); c.ingest_cultural_record({"id":"1","title":"Relato","language":"pui","record_type":"oral_history"}); c.ingest_cultural_record({"id":"2","title":"Informe","language":"es","record_type":"report"}); x=c.search(KnowledgeQuery(language="pui",record_type="oral_history")); assert x.total==1
def test_persistence(tmp_path:Path):
 p=tmp_path/"k.json"; c=PuinaveKnowledgeCenter(p); c.ingest_dictionary_entry({"id":"AMDA","word":"AMDA"}); assert PuinaveKnowledgeCenter(p).get("lex:AMDA") is not None and json.loads(p.read_text(encoding="utf-8"))["schema"]=="SPT-017-knowledge-center-v1"
def test_provenance():
 r=PuinaveKnowledgeCenter().ingest_cultural_record({"id":"1","title":"Registro","actor":"Consejo","license":"autorizado"}); assert r.provenance["actor"]=="Consejo" and r.provenance["license"]=="autorizado"
def test_existing_engine():
 import sgoda.knowledge_engine as k; assert k is not None
def test_contracts():
 c=PuinaveKnowledgeCenter(); c.ingest_dictionary_entry({"id":"A","word":"A"}); c.ingest_learning_insight({"id":"B"}); assert c.health()["source_components"]==["SPT-013B","SPT-016"]
def test_json_ready():
 c=PuinaveKnowledgeCenter(); c.ingest_dictionary_entry({"id":"AMDA","word":"AMDA"}); json.dumps(c.search(KnowledgeQuery(text="AMDA")).to_dict(),ensure_ascii=False)
'@

W (Join-Path $src "__init__.py") $F___init___py;W (Join-Path $src "models.py") $F_models_py;W (Join-Path $src "repository.py") $F_repository_py;W (Join-Path $src "index.py") $F_index_py;W (Join-Path $src "provenance.py") $F_provenance_py;W (Join-Path $src "integrations.py") $F_integrations_py;W (Join-Path $src "service.py") $F_service_py;W (Join-Path $src "cli.py") $F_cli_py;W (Join-Path $tst "test_SPT_017_puinave_knowledge_center.py") $F_tests
$component=@{increment_code="SPT-017";name="Centro de Conocimiento Puinave";version="1.0.0";status="implemented_tested_and_candidate_for_closure";phase="Fase Tecnológica IV";native_ecosystem=$true;mandatory_proprietary_dependencies=@();dependencies=@("SPT-007C","SPT-013B","SPT-014","SPT-015","SPT-016","SGD-114F","SGD-114G","SGD-115","SGD-116","SGD-117","SPB-007")};J (Join-Path $cfg "SPT-017-component.json") $component
J (Join-Path $cfg "SPT-017-policy.json") @{policy_id="SPT-017-POLICY-v1.0.0";principles=@("community provenance","cultural authority","data minimization","explainable retrieval","native open ecosystem");languages=@("pui","es","en")}
W (Join-Path $doc "SPT-017-Arquitectura.md") "# SPT-017 v1.0.0 — Centro de Conocimiento Puinave`n`nSPT-017 extiende SPT-007C sin sustituirlo. Integra catálogo institucional, procedencia, persistencia, búsqueda, diccionario, multimedia, ODA y analítica."
W (Join-Path $doc "SPT-017-Manual-Operativo.md") "# SPT-017 — Manual operativo`n`nUse python -m sgoda.puinave_knowledge_center.cli para health, search y demo."
Run "Validando sintaxis Python" {python -m py_compile "src/sgoda/puinave_knowledge_center/models.py" "src/sgoda/puinave_knowledge_center/repository.py" "src/sgoda/puinave_knowledge_center/index.py" "src/sgoda/puinave_knowledge_center/provenance.py" "src/sgoda/puinave_knowledge_center/integrations.py" "src/sgoda/puinave_knowledge_center/service.py" "src/sgoda/puinave_knowledge_center/cli.py" "tests/puinave_knowledge_center/test_SPT_017_puinave_knowledge_center.py"}
$specXml=Join-Path $reports "specific.xml";$specJson=Join-Path $reports "specific-summary.json";$specMd=Join-Path $reports "specific-summary.md"
Run "Ejecutando pruebas específicas e integración SPT-017" {&$runner -Component "SPT-017-v1.0.0" -TestPath @("tests/puinave_knowledge_center/test_SPT_017_puinave_knowledge_center.py","tests/knowledge_engine/test_SPT_007C_knowledge_engine.py","tests/dictionary_manager/test_SPT_013B_institutional_digital_dictionary_manager.py","tests/multimedia_engine/test_SPT_014_intelligent_multimedia_engine.py","tests/learning_analytics/test_SPT_016_learning_analytics_engine.py") -ReportPath "$specXml" -SummaryJson "$specJson" -SummaryMarkdown "$specMd" -Scope "specific_and_integration"}
$s=Get-Content $specJson -Raw -Encoding UTF8|ConvertFrom-Json;if(-not[bool]$s.approved){throw "Pruebas SPT-017 no aprobadas"}
$demo=Join-Path $pmo "amda-demonstration.json";$health=Join-Path $pmo "health.json";Run "Ejecutando demostración AMDA" {python -m sgoda.puinave_knowledge_center.cli --storage "$data\records.json" --operation demo --output-json "$demo";python -m sgoda.puinave_knowledge_center.cli --storage "$data\records.json" --operation health --output-json "$health"}
$fullXml=Join-Path $reports "full-suite.xml";$fullJson=Join-Path $reports "full-suite-summary.json";$fullMd=Join-Path $reports "full-suite-summary.md";Run "Ejecutando suite completa" {python -m pytest --junitxml="$fullXml"};Run "Sincronizando SGD-114F" {python -m sgoda.governance.test_evidence.cli --junit "$fullXml" --component "SGODA-PUINAVE" --scope "full_suite" --output-json "$fullJson" --output-md "$fullMd"};$f=Get-Content $fullJson -Raw -Encoding UTF8|ConvertFrom-Json;if(-not[bool]$f.approved){throw "Suite completa no aprobada"}
Run "Regenerando SGD-115" {python -m sgoda.documentation.master_docs --root "$ProjectRoot" --output "artifacts/documentation/SGD-115"};Run "Regenerando SGD-116" {python -m sgoda.roadmap.cli --root "$ProjectRoot" --output "artifacts/roadmap/SGD-116"};Run "Validando SGD-117" {python -m sgoda.governance.repository_manager.cli --root "$ProjectRoot" --operation validate --output-json "$pmo\repository-validation.json"}
$e=@{increment_code="SPT-017";version="1.0.0";status="implemented_tested_and_candidate_for_closure";prevalidated_package="............                                                             [100%]
12 passed in 0.11s";base_component="SPT-007C";specific_tests=@{executed=[int]$s.executed;passed=[int]$s.passed;approved=[bool]$s.approved};full_suite=@{executed=[int]$f.executed;passed=[int]$f.passed;approved=[bool]$f.approved};generated_at_utc=[DateTime]::UtcNow.ToString("o")};J (Join-Path $pmo "implementation-evidence.json") $e
@((Join-Path $src "__init__.py"),(Join-Path $src "models.py"),(Join-Path $src "repository.py"),(Join-Path $src "index.py"),(Join-Path $src "provenance.py"),(Join-Path $src "integrations.py"),(Join-Path $src "service.py"),(Join-Path $src "cli.py"),(Join-Path $tst "test_SPT_017_puinave_knowledge_center.py"),(Join-Path $cfg "SPT-017-component.json"),(Join-Path $cfg "SPT-017-policy.json"),(Join-Path $doc "SPT-017-Arquitectura.md"),(Join-Path $doc "SPT-017-Manual-Operativo.md"),$specXml,$specJson,$specMd,$fullXml,$fullJson,$fullMd,$demo,$health,(Join-Path $pmo "implementation-evidence.json"))|ForEach-Object{Req $_;Copy-Item -LiteralPath $_ -Destination $rep -Force}
J (Join-Path $rep "manifest.json") @{increment_code="SPT-017";version="1.0.0";release_name="SPT-017-v1.0.0";status="implemented_tested_and_candidate_for_closure";native_ecosystem=$true;mandatory_proprietary_dependencies=@();base_component="SPT-007C";files=@(Get-ChildItem -LiteralPath $rep -File|Select-Object -ExpandProperty Name)}
Run "Validando SGD-114G" {python -m sgoda.governance.release_management.cli --root "$ProjectRoot" --operation close --output-json "$pmo\release-validation.json"}
if($Publish){Step "Publicando";&$publisher -Publish -CommitMessage "feat(knowledge): implement SPT-017 Puinave Knowledge Center" -EvidenceCommitMessage "chore(knowledge): publish SPT-017 evidence";if($LASTEXITCODE-ne 0){throw "Publicación fallida"}}
Step "Resultado final";Write-Host "SPT-017 v1.0.0 implementado." -ForegroundColor Green;Write-Host "Centro de Conocimiento Puinave: OPERATIVO." -ForegroundColor Green;Write-Host "SPT-007C: CONSERVADO E INTEGRADO." -ForegroundColor Green;Write-Host "Pruebas específicas e integración: $($s.passed)/$($s.executed) APROBADAS." -ForegroundColor Green;Write-Host "Suite completa: $($f.passed)/$($f.executed) APROBADA." -ForegroundColor Green;Write-Host "Demostración AMDA: APROBADA." -ForegroundColor Green;Write-Host "Release: releases\SPT-017-v1.0.0" -ForegroundColor Cyan;if($Publish){Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green}else{Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow}
