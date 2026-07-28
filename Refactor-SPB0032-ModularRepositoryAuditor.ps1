[CmdletBinding()]
param(
  [string]$RepositoryRoot = (Get-Location).Path,
  [switch]$Force,
  [switch]$RunTests,
  [switch]$RunAudit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
Set-Location $RepositoryRoot

function Save-Utf8([string]$Path,[string]$Text) {
  $full = Join-Path $RepositoryRoot $Path
  $parent = Split-Path -Parent $full
  if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  if ((Test-Path $full) -and -not $Force) {
    Write-Host "[CONSERVADO] $Path" -ForegroundColor Yellow
    return
  }
  [IO.File]::WriteAllText($full,$Text,[Text.UTF8Encoding]::new($false))
  Write-Host "[CREADO] $Path" -ForegroundColor Green
}

if (-not (Test-Path ".git")) { throw "Ejecute desde la raíz Git oficial." }

@(
 "src/sgoda/pmo/audit/checks",
 "src/sgoda/pmo/audit/reporting",
 "tests/pmo/audit",
 "scripts",
 "docs/05_Auditoria",
 "artifacts/audit/spb-003.2",
 ".github/workflows"
) | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

Save-Utf8 "src/sgoda/pmo/audit/models.py" @'
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any

class Severity(str, Enum):
    INFO="INFO"; MEDIUM="MEDIUM"; HIGH="HIGH"; CRITICAL="CRITICAL"

class Status(str, Enum):
    PASS="PASS"; WARN="WARN"; FAIL="FAIL"; SKIP="SKIP"

@dataclass(frozen=True)
class Finding:
    code: str
    category: str
    title: str
    severity: Severity
    status: Status
    evidence: str=""
    recommendation: str=""

    def to_dict(self) -> dict[str, Any]:
        data=asdict(self)
        data["severity"]=self.severity.value
        data["status"]=self.status.value
        return data

@dataclass
class AuditResult:
    repository: str=""
    project: str="SGODA-PUINAVE"
    scope: str="SPB-003.2 - Auditoría modular de cierre"
    generated_at: str=field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    branch: str=""
    commit: str=""
    findings: list[Finding]=field(default_factory=list)
    inventory: dict[str,Any]=field(default_factory=dict)
    verdict: str="PENDING"
    compliance_percentage: float=0.0

    def finalize(self):
        evaluated=[f for f in self.findings if f.status != Status.SKIP]
        passed=sum(f.status == Status.PASS for f in evaluated)
        self.compliance_percentage=round(100*passed/len(evaluated),2) if evaluated else 0.0
        blocking=any(f.status == Status.FAIL and f.severity in {Severity.HIGH,Severity.CRITICAL} for f in evaluated)
        failures=any(f.status == Status.FAIL for f in evaluated)
        warnings=any(f.status == Status.WARN for f in evaluated)
        self.verdict="NOT_APPROVED" if blocking else ("APPROVED_WITH_ACTIONS" if failures or warnings else "APPROVED")
        return self

    def to_dict(self):
        return {
            "project":self.project,"scope":self.scope,"generated_at":self.generated_at,
            "repository":self.repository,"branch":self.branch,"commit":self.commit,
            "verdict":self.verdict,"compliance_percentage":self.compliance_percentage,
            "inventory":self.inventory,"findings":[f.to_dict() for f in self.findings],
        }
'@

Save-Utf8 "src/sgoda/pmo/audit/context.py" @'
import subprocess
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True)
class AuditContext:
    root: Path

    @classmethod
    def create(cls,path):
        root=Path(path).resolve()
        if not root.is_dir(): raise ValueError(f"Repositorio inválido: {root}")
        return cls(root)

    def git(self,*args):
        try:
            p=subprocess.run(["git",*args],cwd=self.root,capture_output=True,text=True,encoding="utf-8",errors="replace")
        except OSError as exc:
            return False,str(exc)
        return p.returncode == 0,(p.stdout or p.stderr).strip()
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/base.py" @'
from abc import ABC,abstractmethod

class AuditCheck(ABC):
    code="AIR-BASE"
    category="GENERAL"
    name="Control base"

    @abstractmethod
    def run(self,context):
        raise NotImplementedError
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/structure.py" @'
from .base import AuditCheck
from ..models import Finding,Severity,Status

class StructureCheck(AuditCheck):
    code="AIR-STR"; category="STRUCTURE"; name="Estructura institucional"
    required=(".github","docs","knowledge","scripts","src","tests","README.md")

    def run(self,context):
        findings=[]; missing=[]
        for item in self.required:
            exists=(context.root/item).exists()
            if not exists: missing.append(item)
            findings.append(Finding(
                f"{self.code}-{len(findings)+1:03d}",self.category,f"Elemento requerido: {item}",
                Severity.HIGH if item in {"src","tests","README.md"} else Severity.MEDIUM,
                Status.PASS if exists else Status.FAIL,str(context.root/item),
                "" if exists else f"Crear, restaurar o justificar {item}."
            ))
        return findings,{"missing":missing}
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/git_repository.py" @'
from .base import AuditCheck
from ..models import Finding,Severity,Status

class GitRepositoryCheck(AuditCheck):
    code="AIR-GIT"; category="GIT"; name="Gobierno Git"
    tags={"spb-003.2","spb-003.2-baseline-v1.0","v0.3.2","v1.0.0-spb0032"}

    def run(self,context):
        findings=[]; inventory={}
        ok,value=context.git("rev-parse","--is-inside-work-tree")
        valid=ok and value.lower()=="true"
        findings.append(Finding("AIR-GIT-001",self.category,"Repositorio Git válido",Severity.CRITICAL,Status.PASS if valid else Status.FAIL,value,"Ejecutar desde la raíz oficial."))
        if not valid: return findings,inventory
        _,branch=context.git("branch","--show-current")
        _,commit=context.git("rev-parse","HEAD")
        _,dirty=context.git("status","--porcelain")
        _,remote=context.git("remote","-v")
        _,tags=context.git("tag","--list")
        tag_list=[x for x in tags.splitlines() if x]
        inventory={"branch":branch,"commit":commit,"dirty":dirty.splitlines(),"remotes":remote.splitlines(),"tags":tag_list}
        findings += [
          Finding("AIR-GIT-002",self.category,"Árbol Git limpio",Severity.HIGH,Status.PASS if not dirty else Status.FAIL,dirty or "Limpio","Confirmar o descartar cambios."),
          Finding("AIR-GIT-003",self.category,"Remoto oficial configurado",Severity.HIGH,Status.PASS if remote else Status.FAIL,remote,"Configurar GitHub."),
          Finding("AIR-GIT-004",self.category,"Tag de cierre",Severity.MEDIUM,Status.PASS if any(t.lower() in self.tags for t in tag_list) else Status.WARN,", ".join(tag_list) or "Sin tag","Crear el tag solo después del dictamen APPROVED.")
        ]
        return findings,inventory
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/documentation.py" @'
from .base import AuditCheck
from ..models import Finding,Severity,Status

class DocumentationCheck(AuditCheck):
    code="AIR-DOC"; category="DOCUMENTATION"; name="Documentación"
    documents={"DMP":"*DMP*","SGD-100":"*SGD-100*","Dashboard":"*Dashboard*","Informe Ejecutivo":"*Informe*Ejecutivo*"}

    def run(self,context):
        roots=[p for p in (context.root/"docs",context.root/"artifacts") if p.exists()]
        findings=[]; inventory={}
        for name,pattern in self.documents.items():
            matches=sorted({str(p.relative_to(context.root)) for root in roots for p in root.rglob(pattern) if p.is_file()})
            mandatory=name in {"DMP","SGD-100"}
            inventory[name]=matches
            findings.append(Finding(
              f"AIR-DOC-{len(findings)+1:03d}",self.category,f"Documento: {name}",
              Severity.HIGH if mandatory else Severity.MEDIUM,
              Status.PASS if matches else (Status.FAIL if mandatory else Status.WARN),
              "; ".join(matches) or "No encontrado","" if matches else f"Generar o ubicar {name}."
            ))
        return findings,inventory
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/nomenclature.py" @'
import re
from collections import Counter
from .base import AuditCheck
from ..models import Finding,Severity,Status

class NomenclatureCheck(AuditCheck):
    code="AIR-NOM"; category="NOMENCLATURE"; name="Nomenclatura"
    official={"SPB","SGD","ADR","ACT","CAT","EVD","TST","REL","BL","GUI","MAN","PRC","RDM","DGM","INF","DSH","ESP"}
    token=re.compile(r"\b([A-Z]{2,10})-(?=\d)")
    suffixes={".md",".txt",".py",".json",".yml",".yaml",".toml"}
    ignored={".git",".venv","venv","__pycache__","node_modules","artifacts"}

    def run(self,context):
        used=Counter()
        for p in context.root.rglob("*"):
            if not p.is_file() or p.suffix.lower() not in self.suffixes or any(x in self.ignored for x in p.parts): continue
            try: used.update(self.token.findall(p.read_text(encoding="utf-8",errors="ignore")))
            except OSError: pass
        unknown=sorted(set(used)-self.official)
        norms=list((context.root/"docs").rglob("*SGD-100*")) if (context.root/"docs").exists() else []
        return [
          Finding("AIR-NOM-001",self.category,"Norma SGD-100",Severity.HIGH,Status.PASS if norms else Status.FAIL,"; ".join(str(p.relative_to(context.root)) for p in norms) or "No encontrada","Crear o aprobar SGD-100."),
          Finding("AIR-NOM-002",self.category,"Prefijos no normalizados",Severity.MEDIUM,Status.PASS if not unknown else Status.WARN,", ".join(unknown) or "Ninguno","Revisar y actualizar SGD-100.")
        ],{"usage":dict(used),"unknown":unknown}
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/tests_inventory.py" @'
from .base import AuditCheck
from ..models import Finding,Severity,Status

class TestsInventoryCheck(AuditCheck):
    code="AIR-TST"; category="TESTS"; name="Pruebas"

    def run(self,context):
        pmo=list((context.root/"tests").rglob("test_*.py")) if (context.root/"tests").exists() else []
        builder=list((context.root/"builder/tests").rglob("test_*.py")) if (context.root/"builder/tests").exists() else []
        nested=context.root/context.root.name
        duplicate=nested.exists()
        return [
          Finding("AIR-TST-001",self.category,"Pruebas PMO",Severity.HIGH,Status.PASS if pmo else Status.FAIL,str(len(pmo)),"Crear pruebas PMO."),
          Finding("AIR-TST-002",self.category,"Pruebas Builder separadas",Severity.MEDIUM,Status.PASS if builder else Status.WARN,str(len(builder)),"Ejecutarlas desde builder/."),
          Finding("AIR-TST-003",self.category,"Sin repositorio anidado",Severity.HIGH,Status.FAIL if duplicate else Status.PASS,str(nested) if duplicate else "No detectado","Mover o eliminar el clon anidado.")
        ],{"pmo_files":len(pmo),"builder_files":len(builder),"nested_repository":str(nested) if duplicate else None}
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/traceability.py" @'
from .base import AuditCheck
from ..models import Finding,Severity,Status

class TraceabilityCheck(AuditCheck):
    code="AIR-TRC"; category="TRACEABILITY"; name="Trazabilidad"
    required={
      "Código auditor":"src/sgoda/pmo/audit",
      "Pruebas auditor":"tests/pmo/audit",
      "Workflow":".github/workflows/spb-003-2-closure-audit.yml",
      "Documento arquitectura":"docs/05_Auditoria",
      "Expediente":"artifacts/audit/spb-003.2"
    }

    def run(self,context):
        findings=[]
        for name,relative in self.required.items():
            exists=(context.root/relative).exists()
            findings.append(Finding(f"AIR-TRC-{len(findings)+1:03d}",self.category,name,Severity.HIGH,Status.PASS if exists else Status.FAIL,relative,"" if exists else f"Incorporar {name}."))
        return findings,self.required
'@

Save-Utf8 "src/sgoda/pmo/audit/checks/__init__.py" @'
from .documentation import DocumentationCheck
from .git_repository import GitRepositoryCheck
from .nomenclature import NomenclatureCheck
from .structure import StructureCheck
from .tests_inventory import TestsInventoryCheck
from .traceability import TraceabilityCheck
'@

Save-Utf8 "src/sgoda/pmo/audit/orchestrator.py" @'
from .context import AuditContext
from .models import AuditResult
from .checks import DocumentationCheck,GitRepositoryCheck,NomenclatureCheck,StructureCheck,TestsInventoryCheck,TraceabilityCheck

class RepositoryAuditOrchestrator:
    def __init__(self,repository,checks=None):
        self.context=AuditContext.create(repository)
        self.checks=checks or [StructureCheck(),GitRepositoryCheck(),DocumentationCheck(),NomenclatureCheck(),TestsInventoryCheck(),TraceabilityCheck()]

    def run(self):
        result=AuditResult(repository=str(self.context.root))
        for check in self.checks:
            findings,data=check.run(self.context)
            result.findings.extend(findings)
            result.inventory[check.code]={"name":check.name,"category":check.category,"data":data}
        ok,result.branch=self.context.git("branch","--show-current")
        ok,result.commit=self.context.git("rev-parse","HEAD")
        return result.finalize()
'@

Save-Utf8 "src/sgoda/pmo/audit/reporting/reporters.py" @'
import json
from pathlib import Path

class JsonReporter:
    def write(self,result,path):
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(result.to_dict(),ensure_ascii=False,indent=2),encoding="utf-8")
        return path

class MarkdownReporter:
    def write(self,result,path):
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
        lines=[
          "# SGD-401 — Informe de Auditoría Integral del Repositorio","",
          f"- **Proyecto:** {result.project}",f"- **Alcance:** {result.scope}",
          f"- **Rama:** `{result.branch}`",f"- **Commit:** `{result.commit}`",
          f"- **Cumplimiento:** {result.compliance_percentage} %",
          f"- **Dictamen:** **{result.verdict}**","","## Controles","",
          "| Código | Categoría | Control | Severidad | Estado | Evidencia | Recomendación |",
          "|---|---|---|---|---|---|---|"
        ]
        clean=lambda x:str(x).replace("|","\\|").replace("\n"," ")
        for f in result.findings:
            lines.append(f"| {clean(f.code)} | {clean(f.category)} | {clean(f.title)} | {f.severity.value} | {f.status.value} | {clean(f.evidence)} | {clean(f.recommendation)} |")
        path.write_text("\n".join(lines)+"\n",encoding="utf-8")
        return path

class ClosureReporter:
    def write(self,result,path):
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
        decision={"APPROVED":"APTO PARA CIERRE","APPROVED_WITH_ACTIONS":"CIERRE CONDICIONADO","NOT_APPROVED":"NO APTO PARA CIERRE"}[result.verdict]
        path.write_text(
          f"# ACT-003.2 — Acta Técnica de Decisión de Cierre\n\n"
          f"- **Commit:** `{result.commit}`\n- **Cumplimiento:** {result.compliance_percentage} %\n"
          f"- **Decisión:** **{decision}**\n\n"
          "La etiqueta y la Release solo se publican con dictamen `APPROVED`, árbol Git limpio y suites PMO/Builder aprobadas por separado.\n",
          encoding="utf-8"
        )
        return path
'@

Save-Utf8 "src/sgoda/pmo/audit/reporting/__init__.py" @'
from .reporters import ClosureReporter,JsonReporter,MarkdownReporter
'@

Save-Utf8 "src/sgoda/pmo/audit/service.py" @'
from pathlib import Path
from .orchestrator import RepositoryAuditOrchestrator
from .reporting import ClosureReporter,JsonReporter,MarkdownReporter

class RepositoryAuditService:
    def execute(self,repository,output):
        result=RepositoryAuditOrchestrator(repository).run()
        out=Path(output)
        return {
          "result":result,
          "markdown":MarkdownReporter().write(result,out/"SGD-401-informe-auditoria-integral.md"),
          "json":JsonReporter().write(result,out/"SGD-401-informe-auditoria-integral.json"),
          "act":ClosureReporter().write(result,out/"ACT-003.2-acta-tecnica-cierre.md")
        }
'@

Save-Utf8 "src/sgoda/pmo/audit/cli.py" @'
import argparse
from .service import RepositoryAuditService

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--repository",default=".")
    parser.add_argument("--output",default="artifacts/audit/spb-003.2")
    args=parser.parse_args()
    response=RepositoryAuditService().execute(args.repository,args.output)
    result=response["result"]
    print(f"SGD-401: {response['markdown']}")
    print(f"ACT-003.2: {response['act']}")
    print(f"DICTAMEN: {result.verdict}")
    return 0 if result.verdict=="APPROVED" else 2

if __name__=="__main__":
    raise SystemExit(main())
'@

Save-Utf8 "src/sgoda/pmo/audit/__init__.py" @'
from .models import AuditResult,Finding,Severity,Status
from .orchestrator import RepositoryAuditOrchestrator
from .service import RepositoryAuditService

RepositoryAuditor=RepositoryAuditOrchestrator
'@

Save-Utf8 "tests/pmo/audit/conftest.py" @'
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"src"))
'@

Save-Utf8 "tests/pmo/audit/test_modular_auditor.py" @'
from pathlib import Path
from sgoda.pmo.audit.models import AuditResult,Finding,Severity,Status
from sgoda.pmo.audit.orchestrator import RepositoryAuditOrchestrator
from sgoda.pmo.audit.reporting import JsonReporter,MarkdownReporter,ClosureReporter

def test_critical_failure_blocks_closure():
    result=AuditResult(findings=[Finding("X","TEST","Bloqueo",Severity.CRITICAL,Status.FAIL)]).finalize()
    assert result.verdict=="NOT_APPROVED"

def test_orchestrator_runs(tmp_path: Path):
    for item in (".github","docs","knowledge","scripts","src","tests"):
        (tmp_path/item).mkdir()
    (tmp_path/"README.md").write_text("# test",encoding="utf-8")
    result=RepositoryAuditOrchestrator(tmp_path).run()
    assert result.findings

def test_reporters(tmp_path: Path):
    result=AuditResult().finalize()
    assert JsonReporter().write(result,tmp_path/"x.json").exists()
    assert MarkdownReporter().write(result,tmp_path/"x.md").exists()
    assert ClosureReporter().write(result,tmp_path/"act.md").exists()
'@

Save-Utf8 "scripts/Invoke-SPB0032-ModularAudit.ps1" @'
[CmdletBinding()]
param([string]$RepositoryRoot=(Get-Location).Path,[switch]$RunBuilderTests)
$ErrorActionPreference="Stop"
Set-Location $RepositoryRoot
$env:PYTHONPATH=Join-Path $RepositoryRoot "src"

python -m pytest -q tests/pmo/audit
if($LASTEXITCODE -ne 0){ throw "Fallaron las pruebas del Auditor PMO." }

if($RunBuilderTests -and (Test-Path "builder")){
  Push-Location builder
  try{
    python -m pytest -q
    if($LASTEXITCODE -ne 0){ throw "Falló la suite Builder." }
  } finally { Pop-Location }
}

python -m sgoda.pmo.audit.cli --repository $RepositoryRoot --output (Join-Path $RepositoryRoot "artifacts/audit/spb-003.2")
if($LASTEXITCODE -eq 2){ Write-Warning "Existen acciones antes del cierre."; exit 2 }
if($LASTEXITCODE -ne 0){ throw "Falló el Auditor modular." }
'@

Save-Utf8 "docs/05_Auditoria/SGD-401-Arquitectura-Auditor-Modular.md" @'
# SGD-401 — Arquitectura del Auditor Modular

El Auditor del Repositorio queda integrado al PMO Digital mediante:

- contratos en `models.py`;
- contexto Git en `context.py`;
- controles independientes en `checks/`;
- orquestación en `orchestrator.py`;
- generación de SGD-401, JSON y ACT-003.2 en `reporting/`;
- servicio de aplicación y CLI;
- pruebas PMO separadas de la suite Builder.

Cada nuevo control implementa `AuditCheck.run()` y se registra en el orquestador.
El auditor genera evidencia, pero no crea tags ni Releases.
'@

Save-Utf8 ".github/workflows/spb-003-2-closure-audit.yml" @'
name: SPB-003.2 Modular Closure Audit
on:
  push:
    branches: [main, "feature/SPB-003.2-*"]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  pmo-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: python -m pip install --upgrade pip pytest
      - name: Test modular auditor
        env:
          PYTHONPATH: src
        run: python -m pytest -q tests/pmo/audit
      - name: Run closure audit
        env:
          PYTHONPATH: src
        run: python -m sgoda.pmo.audit.cli --repository . --output artifacts/audit/spb-003.2
      - if: always()
        uses: actions/upload-artifact@v4
        with:
          name: spb-003-2-audit-evidence
          path: artifacts/audit/spb-003.2

  builder:
    runs-on: ubuntu-latest
    if: ${{ hashFiles('builder/pyproject.toml') != '' }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - working-directory: builder
        run: python -m pip install -e . pytest
      - working-directory: builder
        run: python -m pytest -q
'@

$env:PYTHONPATH=Join-Path $RepositoryRoot "src"
python -m compileall -q src/sgoda/pmo/audit
if($LASTEXITCODE -ne 0){ throw "Error de sintaxis Python." }

if($RunTests){
  python -m pytest -q tests/pmo/audit
  if($LASTEXITCODE -ne 0){ throw "Fallaron las pruebas modulares." }
}
if($RunAudit){
  python -m sgoda.pmo.audit.cli --repository $RepositoryRoot --output (Join-Path $RepositoryRoot "artifacts/audit/spb-003.2")
  if($LASTEXITCODE -eq 2){ Write-Warning "Instalado; el cierre aún tiene acciones pendientes." }
  elseif($LASTEXITCODE -ne 0){ throw "Falló la auditoría." }
}

Write-Host "`nAuditor modular instalado en el PMO Digital." -ForegroundColor Green
Write-Host "Ejecute: .\scripts\Invoke-SPB0032-ModularAudit.ps1" -ForegroundColor Yellow
Write-Host "Con Builder: .\scripts\Invoke-SPB0032-ModularAudit.ps1 -RunBuilderTests"
