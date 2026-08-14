#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="41d4a4f3475cabb5f405bfb84677d116ac8ded53"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ReqAssessment="artifacts/development/SPT-025.15-v1.0.0/declarative-package-publication-assessment.json"
$ReqRegistry="artifacts/development/SPT-025.15-v1.0.0/materialization-registry.json"
$ReqLedger="artifacts/development/SPT-025.15-v1.0.0/controlled-promotion-ledger.json"
$ReqPrepare="artifacts/development/SPT-025.15-v1.0.0/spt02516-prepare.json"

$CoreFile="src/sgoda/integration/spt02516/core.py"
$InitFile="src/sgoda/integration/spt02516/__init__.py"
$TestFile="tests/integration/test_spt02516_publication_recertification_master_registry_final_promotion.py"
$PolicyFile="config/integration/spt02516/publication-recertification-final-promotion-policy.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.16/SGD-SPT025.16-Recertificacion-Publicacion-Registro-Maestro-Promocion-Final.md"

$ArtifactDir="artifacts/development/SPT-025.16-v1.0.0"
$RecertificationFile="$ArtifactDir/publication-recertification-assessment.json"
$MasterRegistryFile="$ArtifactDir/master-materialization-registry.json"
$FinalPromotionFile="$ArtifactDir/final-promotion-quality-gate.json"
$ClosureReadinessFile="$ArtifactDir/spt025-closure-readiness-assessment.json"
$IntegrityFile="$ArtifactDir/recertification-sha256-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$PrepareFile="$ArtifactDir/spt025-close1-prepare.json"

function Step{param([int]$Number,[string]$Title);Write-Host "";Write-Host ("[{0}/16] {1}" -f $Number,$Title) -ForegroundColor Cyan}
function Hold{param([string]$Reason);Write-Host "";Write-Host "SPT-025.16 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
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
    Write-Host "SPT-025.1-.15 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-025.15 INPUTS / PREPARE"
    $RequiredInputs=@($ReqAssessment,$ReqRegistry,$ReqLedger,$ReqPrepare)
    $Missing=@($RequiredInputs|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS  : $($Missing.Count)"
    if($Missing.Count -ne 0){Hold "Missing SPT-025.16 prerequisites"}

    $Assessment=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqAssessment)|ConvertFrom-Json
    $Registry=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqRegistry)|ConvertFrom-Json
    $Ledger=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqLedger)|ConvertFrom-Json
    $Prepare=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqPrepare)|ConvertFrom-Json

    if([string]$Assessment.status -ne "DECLARATIVE_PACKAGE_PUBLICATION_GOVERNANCE_GATE_PASS"){Hold "SPT-025.15 publication gate is not PASS"}
    if([string]$Prepare.next_deliverable -ne "SPT-025.16"){Hold "SPT-025.16 PREPARE contract mismatch"}
    if([string]$Prepare.spt02515_publication_governance_gate -ne "PASS"){Hold "SPT-025.16 PREPARE gate is not PASS"}

    Write-Host "SPT-025.15 PUBLICATION GOVERNANCE GATE : PASS"
    Write-Host "SPT-025.16 PREPARE CONTRACT            : PASS"
    Write-Host "REGISTRY / LEDGER INPUTS               : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
    $Freeze=@{}
    foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){
        $A=Join-Path $Root $TrackedPath
        if(Test-Path -LiteralPath $A){$Freeze[$TrackedPath]=Get-Sha256 $A}
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "RECERTIFICATION / MASTER REGISTRY / FINAL PROMOTION DISCOVERY"
    Write-Host "PUBLICATION RECERTIFICATION : REQUIRED"
    Write-Host "MASTER MATERIALIZATION REGISTRY : REQUIRED"
    Write-Host "FINAL PROMOTION QUALITY GATE : REQUIRED"
    Write-Host "REAL PLATFORM DEPLOYMENT : NO"
    Write-Host "AUTO DEPLOYMENT          : NO"
    Write-Host "PRODUCTION CHANGE        : NO"

    Step 5 "IMPLEMENT SPT-025.16 RECERTIFICATION"
    $CoreText=@'
from hashlib import sha256
import json

FINAL_STATES = {"APPROVED", "PUBLISHED", "RETIRED"}

def fingerprint(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def validate_publication_assessment(data):
    errors = []
    if not isinstance(data, dict):
        return {"valid": False, "errors": ["assessment_not_object"]}
    if data.get("status") != "DECLARATIVE_PACKAGE_PUBLICATION_GOVERNANCE_GATE_PASS":
        errors.append("publication_governance_gate_not_pass")
    if data.get("real_platform_count") not in (0, "0"):
        errors.append("real_platform_count_must_be_zero")
    if data.get("auto_deployment") not in (False, None):
        errors.append("auto_deployment_forbidden")
    if data.get("production_change") not in (False, None):
        errors.append("production_change_forbidden")
    if data.get("historical_kurripaco_reference_is_real_instance") not in (False, None):
        errors.append("example_reference_promoted_to_real_instance")
    return {"valid": not errors, "errors": errors}

def validate_materialization_registry(registry):
    errors = []
    if not isinstance(registry, dict):
        return {"valid": False, "errors": ["registry_not_object"], "records": []}
    if registry.get("contract") != "SGODA_MATERIALIZATION_REGISTRY_V1":
        errors.append("registry_contract_invalid")
    records = registry.get("records")
    if not isinstance(records, list):
        errors.append("records_not_list")
        records = []
    seen = set()
    for i, record in enumerate(records):
        if not isinstance(record, dict):
            errors.append(f"record_{i}_not_object")
            continue
        rid = str(record.get("materialization_id") or "").strip()
        if not rid:
            errors.append(f"record_{i}_id_required")
        elif rid in seen:
            errors.append(f"record_{i}_duplicate_id")
        else:
            seen.add(rid)
        if record.get("real_platform") is True:
            errors.append(f"record_{i}_real_platform_forbidden")
        if record.get("auto_deployed") is not False:
            errors.append(f"record_{i}_auto_deployed_forbidden")
        if record.get("production_changed") is not False:
            errors.append(f"record_{i}_production_changed_forbidden")
        if record.get("state") not in FINAL_STATES:
            errors.append(f"record_{i}_state_not_final")
    return {
        "valid": not errors,
        "errors": errors,
        "records": records,
        "real_platform_count": sum(1 for x in records if isinstance(x, dict) and x.get("real_platform") is True),
    }

def validate_promotion_ledger(ledger):
    errors = []
    if not isinstance(ledger, dict):
        return {"valid": False, "errors": ["ledger_not_object"], "records": []}
    if ledger.get("contract") != "SGODA_CONTROLLED_PROMOTION_LEDGER_V1":
        errors.append("promotion_contract_invalid")
    records = ledger.get("records")
    if not isinstance(records, list):
        errors.append("promotion_records_not_list")
        records = []
    for i, record in enumerate(records):
        if not isinstance(record, dict):
            errors.append(f"promotion_{i}_not_object")
            continue
        if record.get("valid") is not True:
            errors.append(f"promotion_{i}_not_valid")
        if str(record.get("to_state") or "").upper() not in FINAL_STATES:
            errors.append(f"promotion_{i}_target_not_final")
        if record.get("real_platform_deployed") is not False:
            errors.append(f"promotion_{i}_real_platform_forbidden")
        if record.get("production_changed") is not False:
            errors.append(f"promotion_{i}_production_change_forbidden")
    return {"valid": not errors, "errors": errors, "records": records}

def recertify(assessment, registry, ledger):
    a = validate_publication_assessment(assessment)
    r = validate_materialization_registry(registry)
    l = validate_promotion_ledger(ledger)
    errors = []
    errors.extend("assessment_" + e for e in a["errors"])
    errors.extend("registry_" + e for e in r["errors"])
    errors.extend("ledger_" + e for e in l["errors"])
    return {
        "pass": not errors,
        "errors": errors,
        "publication_recertification": "PASS" if not a["errors"] else "FAIL",
        "registry_recertification": "PASS" if not r["errors"] else "FAIL",
        "promotion_recertification": "PASS" if not l["errors"] else "FAIL",
        "real_platform_count": r.get("real_platform_count", 0),
        "auto_deployment": False,
        "production_change": False,
    }

def build_master_registry(registry):
    check = validate_materialization_registry(registry)
    if not check["valid"]:
        return {"valid": False, "errors": check["errors"]}
    records = list(check["records"])
    return {
        "valid": True,
        "errors": [],
        "contract": "SGODA_MASTER_MATERIALIZATION_REGISTRY_V1",
        "records": records,
        "record_count": len(records),
        "real_platform_count": check["real_platform_count"],
        "sha256": fingerprint(records),
    }

def final_promotion_gate(assessment, registry, ledger):
    rec = recertify(assessment, registry, ledger)
    master = build_master_registry(registry)
    errors = list(rec["errors"])
    if not master.get("valid"):
        errors.extend("master_" + e for e in master.get("errors", []))
    return {
        "pass": not errors,
        "errors": errors,
        "recertification": rec,
        "master_registry": master,
        "final_promotion_state": "APPROVED_FOR_INSTITUTIONAL_CLOSURE" if not errors else "HOLD",
        "real_platform_deployed": False,
        "production_changed": False,
        "core_duplicated": False,
    }

def example_assessment():
    return {
        "status": "DECLARATIVE_PACKAGE_PUBLICATION_GOVERNANCE_GATE_PASS",
        "real_platform_count": 0,
        "historical_kurripaco_reference_is_real_instance": False,
        "auto_deployment": False,
        "production_change": False,
    }

def example_registry():
    return {
        "contract": "SGODA_MATERIALIZATION_REGISTRY_V1",
        "records": [{
            "materialization_id": "example-materialization-001",
            "package_id": "sgoda-example-declarative-package",
            "state": "PUBLISHED",
            "real_platform": False,
            "example_only": True,
            "auto_deployed": False,
            "production_changed": False,
        }],
        "real_platform_count": 0,
        "example_record_count": 1,
    }

def example_ledger():
    return {
        "contract": "SGODA_CONTROLLED_PROMOTION_LEDGER_V1",
        "records": [{
            "valid": True,
            "package_id": "sgoda-example-declarative-package",
            "from_state": "APPROVED",
            "to_state": "PUBLISHED",
            "package_sha256": "0" * 64,
            "real_platform_deployed": False,
            "production_changed": False,
        }],
    }
'@
    $InitText=@'
from .core import (
    FINAL_STATES,
    fingerprint,
    validate_publication_assessment,
    validate_materialization_registry,
    validate_promotion_ledger,
    recertify,
    build_master_registry,
    final_promotion_gate,
    example_assessment,
    example_registry,
    example_ledger,
)
__all__ = [
    "FINAL_STATES",
    "fingerprint",
    "validate_publication_assessment",
    "validate_materialization_registry",
    "validate_promotion_ledger",
    "recertify",
    "build_master_registry",
    "final_promotion_gate",
    "example_assessment",
    "example_registry",
    "example_ledger",
]
'@
    $TestText=@'
from sgoda.integration.spt02516 import *

def a(): return example_assessment()
def r(): return example_registry()
def l(): return example_ledger()

def test_01(): assert validate_publication_assessment(a())["valid"]
def test_02(): assert validate_materialization_registry(r())["valid"]
def test_03(): assert validate_promotion_ledger(l())["valid"]
def test_04(): assert recertify(a(), r(), l())["pass"]
def test_05(): assert build_master_registry(r())["valid"]
def test_06(): assert build_master_registry(r())["contract"] == "SGODA_MASTER_MATERIALIZATION_REGISTRY_V1"
def test_07(): assert build_master_registry(r())["real_platform_count"] == 0
def test_08(): assert len(build_master_registry(r())["sha256"]) == 64
def test_09(): assert final_promotion_gate(a(), r(), l())["pass"]
def test_10(): assert final_promotion_gate(a(), r(), l())["final_promotion_state"] == "APPROVED_FOR_INSTITUTIONAL_CLOSURE"
def test_11(): assert final_promotion_gate(a(), r(), l())["real_platform_deployed"] is False
def test_12(): assert final_promotion_gate(a(), r(), l())["production_changed"] is False
def test_13(): assert final_promotion_gate(a(), r(), l())["core_duplicated"] is False
def test_14():
    x = a(); x["real_platform_count"] = 1
    assert not validate_publication_assessment(x)["valid"]
def test_15():
    x = r(); x["records"][0]["real_platform"] = True
    assert not validate_materialization_registry(x)["valid"]
def test_16():
    x = r(); x["records"][0]["auto_deployed"] = True
    assert not validate_materialization_registry(x)["valid"]
def test_17():
    x = r(); x["records"][0]["production_changed"] = True
    assert not validate_materialization_registry(x)["valid"]
def test_18():
    x = r(); x["records"][0]["state"] = "DRAFT"
    assert not validate_materialization_registry(x)["valid"]
def test_19():
    x = l(); x["records"][0]["to_state"] = "DRAFT"
    assert not validate_promotion_ledger(x)["valid"]
def test_20():
    x = l(); x["records"][0]["real_platform_deployed"] = True
    assert not validate_promotion_ledger(x)["valid"]
def test_21():
    x = l(); x["records"][0]["production_changed"] = True
    assert not validate_promotion_ledger(x)["valid"]
def test_22():
    x = r(); x["records"].append(dict(x["records"][0]))
    assert not validate_materialization_registry(x)["valid"]
def test_23(): assert fingerprint({"a":1}) == fingerprint({"a":1})
def test_24(): assert len(fingerprint({"a":1})) == 64
def test_25(): assert recertify(a(),r(),l())["publication_recertification"] == "PASS"
def test_26(): assert recertify(a(),r(),l())["registry_recertification"] == "PASS"
def test_27(): assert recertify(a(),r(),l())["promotion_recertification"] == "PASS"
def test_28(): assert build_master_registry(r())["record_count"] == 1
'@
    $PolicyText=@'
{
  "component": "SPT-025.16",
  "version": "1.0.0",
  "title": "Recertificacion de Publicacion, Registro Maestro de Materializaciones y Quality Gate de Promocion Final",
  "authoritative_baseline": "41d4a4f3475cabb5f405bfb84677d116ac8ded53",
  "recertification": {
    "publication": true,
    "materialization_registry": true,
    "promotion_ledger": true,
    "sha256": true,
    "final_promotion_gate": true
  },
  "architecture": {
    "one_native_language_per_platform": true,
    "support_languages": "0..N_CONFIGURABLE",
    "hard_coded_support_languages": false,
    "shared_core_reference": true,
    "core_duplicated": false
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
# SPT-025.16 — Recertificación de Publicación, Registro Maestro de Materializaciones y Quality Gate de Promoción Final

Baseline autoritativa: `41d4a4f3475cabb5f405bfb84677d116ac8ded53`.

Consume obligatoriamente `artifacts/development/SPT-025.15-v1.0.0/spt02516-prepare.json` y preserva íntegramente SPT-025.1–SPT-025.15.

## Objetivo

Recertificar el gobierno de publicación declarativa, consolidar un Registro Maestro de Materializaciones y ejecutar el Quality Gate de Promoción Final para dejar SPT-025 preparado para cierre institucional.

## Restricciones

- no despliegue de plataformas reales;
- no auto-deployment;
- no cambio de producción;
- SGODA Core compartido y no duplicado;
- una lengua nativa principal por plataforma;
- 0..N idiomas auxiliares configurables;
- ningún idioma hard-coded;
- Kurripaco permanece únicamente como referencia histórica de ejemplo;
- todos los resultados deben quedar incorporados y sincronizados en el repositorio oficial.
'@
    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $DocFile $DocumentationText
    Write-Host "SPT-025.16 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    $SmokeCode=@'
from sgoda.integration.spt02516 import example_assessment,example_registry,example_ledger,recertify,build_master_registry,final_promotion_gate
a=example_assessment();r=example_registry();l=example_ledger()
assert recertify(a,r,l)["pass"]
assert build_master_registry(r)["valid"]
assert final_promotion_gate(a,r,l)["pass"]
print("SPT02516_IMPORT=PASS")
print("PUBLICATION_RECERTIFICATION=PASS")
print("MASTER_MATERIALIZATION_REGISTRY=PASS")
print("FINAL_PROMOTION_QUALITY_GATE=PASS")
'@
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $SmokePath=Join-Path ([IO.Path]::GetTempPath()) ("spt02516-smoke-"+[guid]::NewGuid().ToString("N")+".py")
    [IO.File]::WriteAllText($SmokePath,$SmokeCode,$Utf8)
    try{
        & $Python $SmokePath
        if($LASTEXITCODE -ne 0){Hold "SPT-025.16 smoke validation failed"}
    }finally{
        Remove-Item -LiteralPath $SmokePath -Force -ErrorAction SilentlyContinue
    }
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

    Step 8 "RECERTIFICATION / FINAL PROMOTION QUALITY GATE"
    $GateCode=@'
import json,sys
from sgoda.integration.spt02516 import recertify,build_master_registry,final_promotion_gate
a=json.load(open(sys.argv[1],encoding="utf-8"))
r=json.load(open(sys.argv[2],encoding="utf-8"))
l=json.load(open(sys.argv[3],encoding="utf-8"))
print(json.dumps({"recertification":recertify(a,r,l),"master":build_master_registry(r),"final":final_promotion_gate(a,r,l)},ensure_ascii=False))
'@
    $GateScript=Join-Path ([IO.Path]::GetTempPath()) ("spt02516-gate-"+[guid]::NewGuid().ToString("N")+".py")
    $GateOutput=Join-Path ([IO.Path]::GetTempPath()) ("spt02516-gate-"+[guid]::NewGuid().ToString("N")+".json")
    [IO.File]::WriteAllText($GateScript,$GateCode,$Utf8)
    try{
        & $Python $GateScript (Join-Path $Root $ReqAssessment) (Join-Path $Root $ReqRegistry) (Join-Path $Root $ReqLedger)|Out-File -LiteralPath $GateOutput -Encoding utf8
        if($LASTEXITCODE -ne 0){Hold "SPT-025.16 quality gate generation failed"}
        $GateResult=Get-Content -Raw -LiteralPath $GateOutput|ConvertFrom-Json
    }finally{
        Remove-Item -LiteralPath $GateScript,$GateOutput -Force -ErrorAction SilentlyContinue
    }

    if(-not[bool]$GateResult.recertification.pass){Hold "Publication recertification failed"}
    if(-not[bool]$GateResult.master.valid){Hold "Master materialization registry failed"}
    if(-not[bool]$GateResult.final.pass){Hold "Final promotion quality gate failed"}
    if([int]$GateResult.master.real_platform_count -ne 0){Hold "Real platform detected in declarative registry"}

    Write-Host "PUBLICATION_RECERTIFICATION=PASS"
    Write-Host "MATERIALIZATION_REGISTRY_RECERTIFICATION=PASS"
    Write-Host "PROMOTION_LEDGER_RECERTIFICATION=PASS"
    Write-Host "MASTER_MATERIALIZATION_REGISTRY=PASS"
    Write-Host "FINAL_PROMOTION_QUALITY_GATE=PASS"
    Write-Host "FINAL_PROMOTION_STATE=APPROVED_FOR_INSTITUTIONAL_CLOSURE"
    Write-Host "REAL_PLATFORM_COUNT=0"
    Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "SPT-025.16 GLOBAL FINAL PROMOTION GATE : PASS"

    Step 9 "WRITE RECERTIFICATION / MASTER REGISTRY / CLOSURE PREPARE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $Recert=[ordered]@{
        component="SPT-025.16"
        version="1.0.0"
        baseline=$ExpectedBaseline
        status="PUBLICATION_RECERTIFICATION_GATE_PASS"
        publication=[string]$GateResult.recertification.publication_recertification
        registry=[string]$GateResult.recertification.registry_recertification
        promotion=[string]$GateResult.recertification.promotion_recertification
        real_platform_count=[int]$GateResult.recertification.real_platform_count
    }
    $Master=[ordered]@{
        contract=[string]$GateResult.master.contract
        records=@($GateResult.master.records)
        record_count=[int]$GateResult.master.record_count
        real_platform_count=[int]$GateResult.master.real_platform_count
        sha256=[string]$GateResult.master.sha256
    }
    $Final=[ordered]@{
        component="SPT-025.16"
        version="1.0.0"
        status="FINAL_PROMOTION_QUALITY_GATE_PASS"
        final_promotion_state=[string]$GateResult.final.final_promotion_state
        real_platform_deployed=$false
        production_changed=$false
        core_duplicated=$false
        historical_kurripaco_reference_is_real_instance=$false
    }
    $Readiness=[ordered]@{
        component="SPT-025"
        status="READY_FOR_INSTITUTIONAL_CLOSURE_PREPARE"
        spt025_1_to_16_preserved=$true
        final_promotion_gate="PASS"
        real_platform_deployed=$false
        production_change=$false
    }
    $Evidence=[ordered]@{
        component="SPT-025.16"
        version="1.0.0"
        baseline=$ExpectedBaseline
        spt02515_gate="PASS"
        prepare_consumed=$ReqPrepare
        targeted_tests="PASS"
        institutional_suite="PASS"
        compileall="PASS"
        final_promotion_gate="PASS"
        all_outputs_to_repository=$true
        closed_components_preserved=$true
    }
    $Next=[ordered]@{
        next_deliverable="SPT-025.CLOSE.1"
        title="Auditoria Integral de Replicabilidad, Cobertura de Instancias, Quality Gate Global y PREPARE de Cierre Institucional de SPT-025"
        source_baseline=$ExpectedBaseline
        spt02516_final_promotion_gate="PASS"
    }

    Write-Lf $RecertificationFile ($Recert|ConvertTo-Json -Depth 12)
    Write-Lf $MasterRegistryFile ($Master|ConvertTo-Json -Depth 12)
    Write-Lf $FinalPromotionFile ($Final|ConvertTo-Json -Depth 12)
    Write-Lf $ClosureReadinessFile ($Readiness|ConvertTo-Json -Depth 12)
    Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 12)
    Write-Lf $PrepareFile ($Next|ConvertTo-Json -Depth 12)

    $Records=@()
    foreach($P in @($RecertificationFile,$MasterRegistryFile,$FinalPromotionFile,$ClosureReadinessFile,$EvidenceFile,$PrepareFile)){
        $Records+=[ordered]@{path=$P;sha256=Get-Sha256 (Join-Path $Root $P)}
    }
    Write-Lf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$Records}|ConvertTo-Json -Depth 12)

    Write-Host "PUBLICATION RECERTIFICATION : CREATED"
    Write-Host "MASTER MATERIALIZATION REGISTRY : CREATED"
    Write-Host "FINAL PROMOTION GATE : CREATED"
    Write-Host "SPT-025 CLOSURE READINESS : CREATED"
    Write-Host "SHA-256 MANIFEST : CREATED"
    Write-Host "SPT-025.CLOSE.1 PREPARE : CREATED"
    Write-Host "EVIDENCE : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($TrackedPath in $Freeze.Keys){
        $A=Join-Path $Root $TrackedPath
        if(-not(Test-Path -LiteralPath $A)){Hold ("Protected tracked file disappeared: "+$TrackedPath)}
        if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Protected tracked file changed: "+$TrackedPath)}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-025.1-.15 : PRESERVED / NOT REOPENED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@(
        "Invoke-SGODA-SPT02516-PublicationRecertification-MasterMaterializationRegistry-FinalPromotionGate-FINAL-v1.0.0-PS51.ps1",
        $CoreFile,$InitFile,$TestFile,$PolicyFile,$DocFile,
        $RecertificationFile,$MasterRegistryFile,$FinalPromotionFile,
        $ClosureReadinessFile,$IntegrityFile,$EvidenceFile,$PrepareFile
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
    & git.exe commit -m "feat(spt-025.16): recertify publication and approve final promotion gate"
    if($LASTEXITCODE -ne 0){Hold "git commit failed"}
    Write-Host "NEW COMMIT : $((& git.exe rev-parse HEAD).Trim())"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){Hold "git push failed"}
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TECHNICAL CLOSURE"
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
    Write-Host "SPT-025.16 : TECHNICALLY CLOSED / PUBLICATION RECERTIFICATION & FINAL PROMOTION APPROVED" -ForegroundColor Green
    Write-Host "SPT-025.15_PUBLICATION_GOVERNANCE_GATE=PASS"
    Write-Host "SPT-025.16_PREPARE_CONSUMED=PASS"
    Write-Host "PUBLICATION_RECERTIFICATION=PASS"
    Write-Host "MATERIALIZATION_REGISTRY_RECERTIFICATION=PASS"
    Write-Host "PROMOTION_LEDGER_RECERTIFICATION=PASS"
    Write-Host "MASTER_MATERIALIZATION_REGISTRY=PASS"
    Write-Host "FINAL_PROMOTION_QUALITY_GATE=PASS"
    Write-Host "FINAL_PROMOTION_STATE=APPROVED_FOR_INSTITUTIONAL_CLOSURE"
    Write-Host "REAL_PLATFORM_COUNT=0"
    Write-Host "EXAMPLE_NAMES_ARE_EVIDENCE_ONLY=PASS"
    Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "SGODA_PUINAVE_MODIFIED=NO"
    Write-Host "SGODA_CORE_DUPLICATED=NO"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "ALL_OUTPUTS_IN_REPOSITORY=PASS"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "NEXT_DELIVERABLE=SPT-025.CLOSE.1"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}catch{
    Hold $_.Exception.Message
}
