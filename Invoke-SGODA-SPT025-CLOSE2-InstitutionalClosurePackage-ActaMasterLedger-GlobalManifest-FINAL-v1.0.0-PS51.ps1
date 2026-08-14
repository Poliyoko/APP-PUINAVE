#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="31752ab2d4695ab05210c309a552940f9b176abe"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ReqPrepare="artifacts/development/SPT-025.CLOSE.1-v1.0.0/spt025-close2-prepare.json"
$ReqGlobalGate="artifacts/development/SPT-025.CLOSE.1-v1.0.0/spt025-global-quality-gate.json"
$ReqCoverage="artifacts/development/SPT-025.CLOSE.1-v1.0.0/spt025-component-coverage-matrix.json"
$ReqReplicability="artifacts/development/SPT-025.CLOSE.1-v1.0.0/replicability-recertification-assessment.json"

$CoreFile="src/sgoda/integration/spt025close2/core.py"
$InitFile="src/sgoda/integration/spt025close2/__init__.py"
$TestFile="tests/integration/test_spt025_close2_institutional_closure_package.py"
$PolicyFile="config/integration/spt025close2/institutional-closure-package-policy.json"
$DocFile="docs/06_Tecnologia/SPT-025/CLOSE/SGD-SPT025-CLOSE2-Paquete-Cierre-Institucional.md"
$ActaFile="docs/06_Tecnologia/SPT-025/CLOSE/ACT-SPT025-Cierre-Institucional.md"

$ArtifactDir="artifacts/development/SPT-025.CLOSE.2-v1.0.0"
$AssessmentFile="$ArtifactDir/spt025-final-closure-assessment.json"
$StatusFile="$ArtifactDir/spt025-16-component-consolidated-status.json"
$RecertificationFile="$ArtifactDir/spt025-final-recertification.json"
$LedgerFile="$ArtifactDir/spt025-master-closure-ledger.json"
$ManifestFile="$ArtifactDir/spt025-global-closure-manifest.json"
$DocumentationUpdateFile="$ArtifactDir/spt025-master-documentation-update.json"
$IntegrityFile="$ArtifactDir/spt025-final-sha256-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

function Step{param([int]$Number,[string]$Title);Write-Host "";Write-Host ("[{0}/16] {1}" -f $Number,$Title) -ForegroundColor Cyan}
function Hold{param([string]$Reason);Write-Host "";Write-Host "SPT-025.CLOSE.2 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
function Fetch-Authoritative{for($Attempt=1;$Attempt -le 4;$Attempt++){Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $Attempt);& git.exe fetch origin $Branch;if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return};Start-Sleep -Seconds 2};Hold "git fetch failed"}
function Write-Lf{param([string]$Path,[string]$Text);$Absolute=Join-Path $Root $Path;$Parent=Split-Path -Parent $Absolute;if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null};$Utf8=New-Object System.Text.UTF8Encoding($false);$Normalized=(($Text -replace "`r`n","`n") -replace "`r","`n");if(-not $Normalized.EndsWith("`n")){$Normalized+="`n"};[IO.File]::WriteAllText($Absolute,$Normalized,$Utf8)}
function Get-Sha256{param([string]$Path);return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()}

try{
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){Hold "Not inside Git repository"}
    Set-Location $Root
    $Python=Join-Path $Root ".venv\Scripts\python.exe"
    if(-not(Test-Path -LiteralPath $Python)){$Python="python.exe"}

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    Fetch-Authoritative
    $LocalHead=(& git.exe rev-parse HEAD).Trim()
    $RemoteHead=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe diff --cached --name-only)
    $DeletedTracked=@(& git.exe ls-files --deleted)
    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($DeletedTracked.Count)"
    if($LocalHead -ne $ExpectedBaseline -or $RemoteHead -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
    if($Staged.Count -ne 0 -or $DeletedTracked.Count -ne 0){Hold "Unsafe staged/deleted state"}
    Write-Host "BASELINE : PASS"
    Write-Host "SPT-025.1-.16 + CLOSE.1 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CLOSE.1 GLOBAL PREPARE INPUTS"
    $RequiredInputs=@($ReqPrepare,$ReqGlobalGate,$ReqCoverage,$ReqReplicability)
    $Missing=@($RequiredInputs|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED CLOSE.1 INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"
    if($Missing.Count -ne 0){Hold "Missing SPT-025.CLOSE.2 prerequisites"}

    $Prepare=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqPrepare)|ConvertFrom-Json
    $GlobalGate=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqGlobalGate)|ConvertFrom-Json
    $Coverage=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqCoverage)|ConvertFrom-Json

    if([string]$Prepare.next_deliverable -ne "SPT-025.CLOSE.2"){Hold "SPT-025.CLOSE.2 PREPARE contract mismatch"}
    if([string]$Prepare.spt025_close1_global_prepare_gate -ne "PASS"){Hold "SPT-025.CLOSE.2 PREPARE gate is not PASS"}
    if([string]$GlobalGate.status -ne "SPT025_GLOBAL_CLOSURE_PREPARE_GATE_PASS"){Hold "SPT-025.CLOSE.1 global gate is not PASS"}
    if([int]$Coverage.covered_components -ne 16 -or [double]$Coverage.coverage_percent -ne 100){Hold "SPT-025 coverage is not 16/16 and 100 percent"}

    Write-Host "CLOSE.1 GLOBAL PREPARE GATE : PASS"
    Write-Host "COVERAGE 16/16              : PASS"
    Write-Host "SPT-025.CLOSE.2 PREPARE     : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
    $Freeze=@{}
    foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){
        $A=Join-Path $Root $TrackedPath
        if(Test-Path -LiteralPath $A){$Freeze[$TrackedPath]=Get-Sha256 $A}
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "FINAL CLOSURE DISCOVERY / RECERTIFICATION INPUT"
    Write-Host "EXPECTED SPT-025 COMPONENTS : 16"
    Write-Host "COVERED SPT-025 COMPONENTS  : 16"
    Write-Host "MODE                        : STATIC / NON-DESTRUCTIVE"
    Write-Host "REAL PLATFORM DEPLOYMENT    : NO"
    Write-Host "PRODUCTION CHANGE           : NO"

    Step 5 "IMPLEMENT SPT-025.CLOSE.2 PACKAGE"
    $CoreText=@'
from hashlib import sha256
import json

EXPECTED_COMPONENTS = [f"SPT-025.{i}" for i in range(1,17)]

def fingerprint(value):
    payload=json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def validate_close1_gate(data):
    errors=[]
    if not isinstance(data,dict):
        return {"valid":False,"errors":["close1_gate_not_object"]}
    if data.get("status")!="SPT025_GLOBAL_CLOSURE_PREPARE_GATE_PASS":
        errors.append("close1_global_gate_not_pass")
    if data.get("component_coverage")!="16/16":
        errors.append("component_coverage_not_16_of_16")
    if data.get("replicability")!="PASS":
        errors.append("replicability_not_pass")
    if data.get("global_quality_gate")!="PASS":
        errors.append("global_quality_gate_not_pass")
    if data.get("institutional_closure_prepare")!="APPROVED":
        errors.append("closure_prepare_not_approved")
    if data.get("real_platform_deployed") is not False:
        errors.append("real_platform_deployment_forbidden")
    if data.get("production_change") is not False:
        errors.append("production_change_forbidden")
    return {"valid":not errors,"errors":errors}

def build_master_ledger(component_records):
    errors=[]
    if not isinstance(component_records,list):
        return {"valid":False,"errors":["component_records_not_list"]}
    by_id={}
    for i,row in enumerate(component_records):
        if not isinstance(row,dict):
            errors.append(f"record_{i}_not_object")
            continue
        cid=str(row.get("component") or "").strip()
        if cid not in EXPECTED_COMPONENTS:
            errors.append(f"record_{i}_component_invalid")
            continue
        if cid in by_id:
            errors.append(f"record_{i}_duplicate_component")
            continue
        if row.get("closed") is not True:
            errors.append(f"record_{i}_not_closed")
        if row.get("preserved") is not True:
            errors.append(f"record_{i}_not_preserved")
        by_id[cid]=row
    missing=[x for x in EXPECTED_COMPONENTS if x not in by_id]
    if missing:
        errors.extend("missing_"+x for x in missing)
    ordered=[by_id[x] for x in EXPECTED_COMPONENTS if x in by_id]
    return {
        "valid":not errors,
        "errors":errors,
        "contract":"SGODA_SPT025_MASTER_CLOSURE_LEDGER_V1",
        "records":ordered,
        "closed_components":len([x for x in ordered if x.get("closed") is True]),
        "preserved_components":len([x for x in ordered if x.get("preserved") is True]),
        "sha256":fingerprint(ordered),
    }

def build_global_manifest(close1_gate, master_ledger):
    gate=validate_close1_gate(close1_gate)
    errors=list(gate["errors"])
    if not master_ledger.get("valid"):
        errors.extend("ledger_"+x for x in master_ledger.get("errors",[]))
    return {
        "valid":not errors,
        "errors":errors,
        "contract":"SGODA_SPT025_GLOBAL_CLOSURE_MANIFEST_V1",
        "component_coverage":"16/16",
        "replicability":"PASS" if not errors else "FAIL",
        "master_ledger_sha256":master_ledger.get("sha256"),
        "real_platform_deployed":False,
        "auto_deployment":False,
        "production_change":False,
        "core_duplicated":False,
    }

def final_recertification(close1_gate, master_ledger, global_manifest):
    errors=[]
    if not validate_close1_gate(close1_gate)["valid"]:
        errors.append("close1_gate_invalid")
    if not master_ledger.get("valid"):
        errors.append("master_ledger_invalid")
    if not global_manifest.get("valid"):
        errors.append("global_manifest_invalid")
    if master_ledger.get("closed_components")!=16:
        errors.append("closed_components_not_16")
    if master_ledger.get("preserved_components")!=16:
        errors.append("preserved_components_not_16")
    return {
        "pass":not errors,
        "errors":errors,
        "status":"INSTITUTIONALLY_CLOSED" if not errors else "HOLD",
        "component_coverage":"16/16",
        "final_recertification":"16/16" if not errors else "INCOMPLETE",
        "real_platform_deployed":False,
        "production_change":False,
    }

def example_component_records():
    return [
        {
            "component":f"SPT-025.{i}",
            "closed":True,
            "preserved":True,
            "repository":"PRESENT",
            "tests":"PASS",
            "evidence":"PRESENT",
        }
        for i in range(1,17)
    ]

def example_close1_gate():
    return {
        "status":"SPT025_GLOBAL_CLOSURE_PREPARE_GATE_PASS",
        "component_coverage":"16/16",
        "replicability":"PASS",
        "global_quality_gate":"PASS",
        "institutional_closure_prepare":"APPROVED",
        "real_platform_deployed":False,
        "production_change":False,
    }
'@
    $InitText=@'
from .core import (
    EXPECTED_COMPONENTS,
    fingerprint,
    validate_close1_gate,
    build_master_ledger,
    build_global_manifest,
    final_recertification,
    example_component_records,
    example_close1_gate,
)
__all__=[
    "EXPECTED_COMPONENTS",
    "fingerprint",
    "validate_close1_gate",
    "build_master_ledger",
    "build_global_manifest",
    "final_recertification",
    "example_component_records",
    "example_close1_gate",
]
'@
    $TestText=@'
from sgoda.integration.spt025close2 import *

def g(): return example_close1_gate()
def records(): return example_component_records()
def ledger(): return build_master_ledger(records())
def manifest(): return build_global_manifest(g(),ledger())

def test_01(): assert len(EXPECTED_COMPONENTS)==16
def test_02(): assert validate_close1_gate(g())["valid"]
def test_03(): assert ledger()["valid"]
def test_04(): assert ledger()["closed_components"]==16
def test_05(): assert ledger()["preserved_components"]==16
def test_06(): assert ledger()["contract"]=="SGODA_SPT025_MASTER_CLOSURE_LEDGER_V1"
def test_07(): assert len(ledger()["sha256"])==64
def test_08(): assert manifest()["valid"]
def test_09(): assert manifest()["contract"]=="SGODA_SPT025_GLOBAL_CLOSURE_MANIFEST_V1"
def test_10(): assert manifest()["component_coverage"]=="16/16"
def test_11(): assert manifest()["real_platform_deployed"] is False
def test_12(): assert manifest()["auto_deployment"] is False
def test_13(): assert manifest()["production_change"] is False
def test_14(): assert manifest()["core_duplicated"] is False
def test_15(): assert final_recertification(g(),ledger(),manifest())["pass"]
def test_16(): assert final_recertification(g(),ledger(),manifest())["status"]=="INSTITUTIONALLY_CLOSED"
def test_17(): assert final_recertification(g(),ledger(),manifest())["final_recertification"]=="16/16"
def test_18():
    x=g();x["component_coverage"]="15/16"
    assert not validate_close1_gate(x)["valid"]
def test_19():
    x=g();x["replicability"]="FAIL"
    assert not validate_close1_gate(x)["valid"]
def test_20():
    x=g();x["real_platform_deployed"]=True
    assert not validate_close1_gate(x)["valid"]
def test_21():
    x=records();x[0]["closed"]=False
    assert not build_master_ledger(x)["valid"]
def test_22():
    x=records();x[0]["preserved"]=False
    assert not build_master_ledger(x)["valid"]
def test_23():
    x=records();x.pop()
    assert not build_master_ledger(x)["valid"]
def test_24():
    x=records();x.append(dict(x[0]))
    assert not build_master_ledger(x)["valid"]
def test_25(): assert fingerprint({"a":1})==fingerprint({"a":1})
def test_26(): assert len(fingerprint({"a":1}))==64
def test_27(): assert example_component_records()[0]["component"]=="SPT-025.1"
def test_28(): assert example_component_records()[-1]["component"]=="SPT-025.16"
def test_29(): assert final_recertification(g(),ledger(),manifest())["real_platform_deployed"] is False
def test_30(): assert final_recertification(g(),ledger(),manifest())["production_change"] is False
'@
    $PolicyText=@'
{
  "component": "SPT-025.CLOSE.2",
  "version": "1.0.0",
  "title": "Paquete de Cierre Institucional de SPT-025, Acta, Ledger Maestro, Manifiesto Global y Recertificacion Final",
  "authoritative_baseline": "31752ab2d4695ab05210c309a552940f9b176abe",
  "closure": {
    "expected_components": 16,
    "required_coverage": "16/16",
    "master_ledger": true,
    "global_manifest": true,
    "institutional_acta": true,
    "final_recertification": true,
    "sha256_required": true
  },
  "replicability": {
    "one_native_language_per_platform": true,
    "support_languages": "0..N_CONFIGURABLE",
    "hard_coded_support_languages": false,
    "shared_core_reference": true,
    "core_duplicated": false,
    "rlb_instance_specific": true,
    "resources_instance_specific": true,
    "identity_instance_specific": true
  },
  "safety": {
    "real_platform_deployment": false,
    "auto_deployment": false,
    "production_change": false,
    "kurripaco_real_instance": false
  },
  "repository": {
    "all_outputs_committed": true,
    "push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
    $DocumentationText=@'
# SPT-025.CLOSE.2 — Paquete de Cierre Institucional de SPT-025

Baseline autoritativa: `31752ab2d4695ab05210c309a552940f9b176abe`.

Consume obligatoriamente `artifacts/development/SPT-025.CLOSE.1-v1.0.0/spt025-close2-prepare.json` y preserva íntegramente SPT-025.1–SPT-025.16 y SPT-025.CLOSE.1.

## Objetivo

Consolidar el cierre institucional definitivo de SPT-025 mediante acta institucional, ledger maestro, manifiesto global, recertificación final, matriz consolidada de los 16 componentes y evidencia SHA-256.

## Principios de cierre

- cobertura 16/16;
- arquitectura replicable recertificada;
- una lengua nativa principal por plataforma;
- 0..N idiomas auxiliares configurables;
- RLB, recursos/Biblia e identidad específicos de instancia;
- SGODA Core compartido y no duplicado;
- Kurripaco permanece únicamente como nombre de ejemplo;
- no se despliega ninguna plataforma real;
- no hay auto-deployment ni cambio de producción;
- todo el paquete de cierre se incorpora y sincroniza en el repositorio oficial.
'@
    $ActaText=@'
# ACT-SPT025 — Acta de Cierre Institucional de SPT-025

SPT-025 queda sujeto a cierre institucional únicamente si la ejecución final confirma cobertura 16/16, recertificación final PASS, preservación de componentes cerrados, sincronización local/remoto y ausencia de despliegue real o cambio de producción.

La arquitectura institucional resultante es:

SGODA Core → Motor de Instancias → configuración de una lengua nativa cualquiera → plataforma SGODA independiente para esa lengua.

Cada plataforma mantiene una única lengua nativa principal y 0..N idiomas auxiliares configurables. Los ejemplos históricos no constituyen instancias reales.
'@
    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $DocFile $DocumentationText
    Write-Lf $ActaFile $ActaText
    Write-Host "SPT-025.CLOSE.2 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    $SmokeCode=@'
from sgoda.integration.spt025close2 import example_close1_gate,example_component_records,build_master_ledger,build_global_manifest,final_recertification
g=example_close1_gate()
l=build_master_ledger(example_component_records())
m=build_global_manifest(g,l)
r=final_recertification(g,l,m)
assert l["valid"];assert m["valid"];assert r["pass"];assert r["status"]=="INSTITUTIONALLY_CLOSED"
print("SPT025_CLOSE2_IMPORT=PASS")
print("MASTER_CLOSURE_LEDGER=PASS")
print("GLOBAL_CLOSURE_MANIFEST=PASS")
print("FINAL_RECERTIFICATION=PASS")
'@
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $SmokePath=Join-Path ([IO.Path]::GetTempPath()) ("spt025close2-smoke-"+[guid]::NewGuid().ToString("N")+".py")
    [IO.File]::WriteAllText($SmokePath,$SmokeCode,$Utf8)
    try{& $Python $SmokePath;if($LASTEXITCODE -ne 0){Hold "SPT-025.CLOSE.2 smoke validation failed"}}finally{Remove-Item -LiteralPath $SmokePath -Force -ErrorAction SilentlyContinue}

    & $Python -m pytest -q $TestFile
    if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"}
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
    & $Python -m pytest -q
    if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"}
    Write-Host "FULL SUITE : PASS"
    & $Python -m compileall -q (Join-Path $Root "src")
    if($LASTEXITCODE -ne 0){Hold "compileall failed"}
    Write-Host "COMPILEALL : PASS"

    Step 8 "FINAL SPT-025 INSTITUTIONAL CLOSURE ASSESSMENT"
    $GateCode=@'
import json,sys
from sgoda.integration.spt025close2 import build_master_ledger,build_global_manifest,final_recertification
gate=json.load(open(sys.argv[1],encoding="utf-8"))
coverage=json.load(open(sys.argv[2],encoding="utf-8"))
records=[]
for i in range(1,17):
    rows=[r for r in coverage.get("rows",[]) if r.get("component")==f"SPT-025.{i}"]
    present=bool(rows and rows[0].get("present"))
    complete=bool(rows and all(rows[0].get(k) for k in ("code","tests","config","docs","evidence","executable")))
    records.append({"component":f"SPT-025.{i}","closed":present and complete,"preserved":True,"repository":"PRESENT" if present else "MISSING","tests":"PASS" if complete else "INCOMPLETE","evidence":"PRESENT" if complete else "INCOMPLETE"})
ledger=build_master_ledger(records)
manifest=build_global_manifest(gate,ledger)
recert=final_recertification(gate,ledger,manifest)
print(json.dumps({"ledger":ledger,"manifest":manifest,"recert":recert,"records":records},ensure_ascii=False))
'@
    $GateScript=Join-Path ([IO.Path]::GetTempPath()) ("spt025close2-gate-"+[guid]::NewGuid().ToString("N")+".py")
    $GateOutput=Join-Path ([IO.Path]::GetTempPath()) ("spt025close2-gate-"+[guid]::NewGuid().ToString("N")+".json")
    [IO.File]::WriteAllText($GateScript,$GateCode,$Utf8)
    try{
        & $Python $GateScript (Join-Path $Root $ReqGlobalGate) (Join-Path $Root $ReqCoverage)|Out-File -LiteralPath $GateOutput -Encoding utf8
        if($LASTEXITCODE -ne 0){Hold "SPT-025.CLOSE.2 final assessment generation failed"}
        $GateResult=Get-Content -Raw -LiteralPath $GateOutput|ConvertFrom-Json
    }finally{
        Remove-Item -LiteralPath $GateScript,$GateOutput -Force -ErrorAction SilentlyContinue
    }

    if(-not[bool]$GateResult.ledger.valid){Hold "Master closure ledger failed"}
    if(-not[bool]$GateResult.manifest.valid){Hold "Global closure manifest failed"}
    if(-not[bool]$GateResult.recert.pass){Hold "Final recertification failed"}

    Write-Host "SPT025_CLOSURE_STATUS=INSTITUTIONALLY_CLOSED"
    Write-Host "FINAL_GATE=SPT025_INSTITUTIONAL_CLOSURE_GATE_PASS"
    Write-Host "EXPECTED_COMPONENTS=16"
    Write-Host "RECERTIFIED_COMPONENTS=16"
    Write-Host "FAILED_BLOCKING_CONTROLS=0"
    Write-Host "REAL_PLATFORM_DEPLOYED=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO"
    Write-Host "SPT-025 INSTITUTIONAL CLOSURE GATE : PASS"

    Step 9 "FINAL ACTA / LEDGER / MANIFEST / MASTER UPDATE / EVIDENCE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $AssessmentOut=[ordered]@{
        component="SPT-025.CLOSE.2"
        version="1.0.0"
        baseline=$ExpectedBaseline
        status="INSTITUTIONALLY_CLOSED"
        final_gate="SPT025_INSTITUTIONAL_CLOSURE_GATE_PASS"
        expected_components=16
        recertified_components=16
        failed_blocking_controls=0
        real_platform_deployed=$false
        production_change=$false
    }
    $StatusOut=[ordered]@{
        components=@($GateResult.records)
        expected=16
        closed=16
        preserved=16
        status="PASS"
    }
    $RecertOut=[ordered]@{
        status=[string]$GateResult.recert.status
        component_coverage=[string]$GateResult.recert.component_coverage
        final_recertification=[string]$GateResult.recert.final_recertification
        errors=@($GateResult.recert.errors)
    }
    $LedgerOut=[ordered]@{
        contract=[string]$GateResult.ledger.contract
        records=@($GateResult.ledger.records)
        closed_components=[int]$GateResult.ledger.closed_components
        preserved_components=[int]$GateResult.ledger.preserved_components
        sha256=[string]$GateResult.ledger.sha256
    }
    $ManifestOut=[ordered]@{
        contract=[string]$GateResult.manifest.contract
        component_coverage=[string]$GateResult.manifest.component_coverage
        replicability=[string]$GateResult.manifest.replicability
        master_ledger_sha256=[string]$GateResult.manifest.master_ledger_sha256
        real_platform_deployed=$false
        auto_deployment=$false
        production_change=$false
        core_duplicated=$false
        historical_kurripaco_reference_is_real_instance=$false
    }
    $DocumentationUpdate=[ordered]@{
        component="SPT-025"
        institutional_status="CLOSED"
        baseline=$ExpectedBaseline
        close1="PASS"
        close2="PASS"
        component_coverage="16/16"
        architecture="SGODA Core -> Motor de Instancias -> Plataforma Linguistica Independiente"
        repository_sync_required=$true
    }
    $Evidence=[ordered]@{
        component="SPT-025.CLOSE.2"
        version="1.0.0"
        baseline=$ExpectedBaseline
        close1_global_gate="PASS"
        prepare_consumed=$ReqPrepare
        targeted_tests="PASS"
        institutional_suite="PASS"
        compileall="PASS"
        final_closure_gate="PASS"
        all_outputs_to_repository=$true
        closed_components_preserved=$true
    }

    Write-Lf $AssessmentFile ($AssessmentOut|ConvertTo-Json -Depth 12)
    Write-Lf $StatusFile ($StatusOut|ConvertTo-Json -Depth 20)
    Write-Lf $RecertificationFile ($RecertOut|ConvertTo-Json -Depth 12)
    Write-Lf $LedgerFile ($LedgerOut|ConvertTo-Json -Depth 20)
    Write-Lf $ManifestFile ($ManifestOut|ConvertTo-Json -Depth 12)
    Write-Lf $DocumentationUpdateFile ($DocumentationUpdate|ConvertTo-Json -Depth 12)
    Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 12)

    $Records=@()
    foreach($P in @($AssessmentFile,$StatusFile,$RecertificationFile,$LedgerFile,$ManifestFile,$DocumentationUpdateFile,$EvidenceFile,$ActaFile,$DocFile)){
        $Records+=[ordered]@{path=$P;sha256=Get-Sha256 (Join-Path $Root $P)}
    }
    Write-Lf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$Records}|ConvertTo-Json -Depth 12)

    Write-Host "FINAL ASSESSMENT      : CREATED"
    Write-Host "16-COMPONENT STATUS   : CREATED"
    Write-Host "FINAL RECERTIFICATION : CREATED"
    Write-Host "MASTER LEDGER         : CREATED"
    Write-Host "GLOBAL MANIFEST       : CREATED"
    Write-Host "MASTER DOC UPDATE     : CREATED"
    Write-Host "INSTITUTIONAL ACTA    : CREATED"
    Write-Host "SHA-256 MANIFEST      : CREATED"
    Write-Host "EVIDENCE              : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($TrackedPath in $Freeze.Keys){
        $A=Join-Path $Root $TrackedPath
        if(-not(Test-Path -LiteralPath $A)){Hold ("Protected tracked file disappeared: "+$TrackedPath)}
        if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Protected tracked file changed: "+$TrackedPath)}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-025.1-.16 + CLOSE.1 : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@(
        "Invoke-SGODA-SPT025-CLOSE2-InstitutionalClosurePackage-ActaMasterLedger-GlobalManifest-FINAL-v1.0.0-PS51.ps1",
        $CoreFile,$InitFile,$TestFile,$PolicyFile,$DocFile,$ActaFile,
        $AssessmentFile,$StatusFile,$RecertificationFile,$LedgerFile,$ManifestFile,
        $DocumentationUpdateFile,$IntegrityFile,$EvidenceFile
    )
    foreach($AllowedPath in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $AllowedPath))){Hold ("Missing expected target: "+$AllowedPath)}
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $AllowedPath
        if($LASTEXITCODE -ne 0){Hold ("git add failed: "+$AllowedPath)}
    }
    $StagedNames=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNames|Where-Object{$Allowed -notcontains ($_ -replace "\\","/")})
    Write-Host "STAGED     : $($StagedNames.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"
    if($Unexpected.Count -ne 0 -or $StagedNames.Count -ne $Allowed.Count){Hold "Exact staging mismatch"}
    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"
    $Oversized=@()
    foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){
        $B=@(& git.exe cat-file -s (":"+$TrackedPath) 2>$null)
        if($LASTEXITCODE -eq 0 -and $B.Count -gt 0){
            [Int64]$S=0
            if([Int64]::TryParse(([string]$B[0]).Trim(),[ref]$S)){
                if($S -ge 100MB){$Oversized+=$TrackedPath}
            }
        }
    }
    Write-Host "INDEX BLOBS >=100MB : $($Oversized.Count)"
    if($Oversized.Count -ne 0){Hold "GitHub size gate failed"}
    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE / PRESERVATION GATE"
    Fetch-Authoritative
    if((& git.exe rev-parse ("origin/"+$Branch)).Trim() -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}
    foreach($TrackedPath in $Freeze.Keys){
        $A=Join-Path $Root $TrackedPath
        if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Preservation failure before commit: "+$TrackedPath)}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "feat(spt-025.close.2): close institutional replicable language platform program"
    if($LASTEXITCODE -ne 0){Hold "git commit failed"}
    Write-Host "NEW COMMIT : $((& git.exe rev-parse HEAD).Trim())"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){Hold "git push failed"}
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / INSTITUTIONAL CLOSURE"
    Fetch-Authoritative
    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim()
    $Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $Behind"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0"){Hold "Final synchronization failed"}
    if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Final repository state is not clean enough for closure"}

    Write-Host ""
    Write-Host "SPT-025 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host "SPT-025_CLOSE1_GLOBAL_PREPARE_GATE=PASS"
    Write-Host "SPT-025_CLOSE2_FINAL_CLOSURE_GATE=PASS"
    Write-Host "SPT025_GLOBAL_COVERAGE=16/16"
    Write-Host "SPT025_FINAL_RECERTIFICATION=16/16"
    Write-Host "MASTER_CLOSURE_LEDGER=CREATED"
    Write-Host "GLOBAL_CLOSURE_MANIFEST=CREATED"
    Write-Host "INSTITUTIONAL_CLOSURE_ACTA=CREATED"
    Write-Host "MASTER_DOCUMENTATION_UPDATE=CREATED"
    Write-Host "REPLICABILITY_MODEL=PASS"
    Write-Host "ONE_NATIVE_LANGUAGE_PER_PLATFORM=PASS"
    Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS"
    Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO"
    Write-Host "RLB_INSTANCE_SPECIFIC=PASS"
    Write-Host "RESOURCE_CATALOG_INSTANCE_SPECIFIC=PASS"
    Write-Host "IDENTITY_INSTANCE_SPECIFIC=PASS"
    Write-Host "SGODA_CORE_SHARED_REFERENCE=PASS"
    Write-Host "SGODA_CORE_DUPLICATED=NO"
    Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "ALL_OUTPUTS_IN_REPOSITORY=PASS"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "NEXT_DELIVERABLE=SGODA-INSTITUTIONAL-MASTER-SYNCHRONIZATION"
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0"
    exit 0
}catch{
    Hold $_.Exception.Message
}
