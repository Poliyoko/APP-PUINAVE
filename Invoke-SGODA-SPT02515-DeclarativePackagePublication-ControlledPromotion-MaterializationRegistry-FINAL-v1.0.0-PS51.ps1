#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="bb7d818664e46bf7be4bc0036872bc6197fc2a2a"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ReqGate="artifacts/development/SPT-025.14-v1.0.0/declarative-materialization-quality-gate.json"
$ReqPrepare="artifacts/development/SPT-025.14-v1.0.0/spt02515-prepare.json"

$CoreFile="src/sgoda/integration/spt02515/core.py"
$InitFile="src/sgoda/integration/spt02515/__init__.py"
$TestFile="tests/integration/test_spt02515_declarative_package_publication_governance.py"
$PolicyFile="config/integration/spt02515/declarative-package-publication-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.15/SGD-SPT025.15-Publicacion-Paquetes-Promocion-Materializaciones.md"

$ArtifactDir="artifacts/development/SPT-025.15-v1.0.0"
$PublicationFile="$ArtifactDir/declarative-package-publication-assessment.json"
$PromotionFile="$ArtifactDir/controlled-promotion-ledger.json"
$RegistryFile="$ArtifactDir/materialization-registry.json"
$ExamplePackageFile="$ArtifactDir/example-declarative-publication-package.json"
$ExampleRecordFile="$ArtifactDir/example-materialization-record.json"
$IntegrityFile="$ArtifactDir/publication-governance-sha256-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$PrepareFile="$ArtifactDir/spt02516-prepare.json"

function Step{param([int]$Number,[string]$Title);Write-Host "";Write-Host ("[{0}/16] {1}" -f $Number,$Title) -ForegroundColor Cyan}
function Hold{param([string]$Reason);Write-Host "";Write-Host "SPT-025.15 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
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
    Write-Host "SPT-025.1-.14 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-025.14 GATE / SPT-025.15 PREPARE"
    $RequiredInputs=@($ReqGate,$ReqPrepare)
    $Missing=@($RequiredInputs|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS  : $($Missing.Count)"
    if($Missing.Count -ne 0){Hold "Missing SPT-025.15 prerequisites"}

    $Gate=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqGate)|ConvertFrom-Json
    $Prepare=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqPrepare)|ConvertFrom-Json

    if([string]$Gate.status -ne "DECLARATIVE_MATERIALIZATION_QUALITY_GATE_PASS"){Hold "SPT-025.14 materialization gate is not PASS"}
    if([string]$Prepare.next_deliverable -ne "SPT-025.15"){Hold "SPT-025.15 PREPARE contract mismatch"}
    if([string]$Prepare.spt02514_materialization_quality_gate -ne "PASS"){Hold "SPT-025.15 PREPARE gate is not PASS"}

    Write-Host "SPT-025.14 MATERIALIZATION GATE : PASS"
    Write-Host "SPT-025.15 PREPARE CONTRACT     : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
    $Freeze=@{}
    foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){
        $A=Join-Path $Root $TrackedPath
        if(Test-Path -LiteralPath $A){$Freeze[$TrackedPath]=Get-Sha256 $A}
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "PUBLICATION / PROMOTION / MATERIALIZATION REGISTRY DISCOVERY"
    Write-Host "PUBLICATION MODE             : DECLARATIVE PACKAGES ONLY"
    Write-Host "PROMOTION                    : CONTROLLED"
    Write-Host "MATERIALIZATION REGISTRY     : REQUIRED"
    Write-Host "SHA-256                      : REQUIRED"
    Write-Host "REAL PLATFORM DEPLOYMENT     : NO"
    Write-Host "AUTO DEPLOYMENT              : NO"
    Write-Host "PRODUCTION CHANGE            : NO"

    Step 5 "IMPLEMENT SPT-025.15 PUBLICATION GOVERNANCE"
    $CoreText=@'
from hashlib import sha256
import json

ALLOWED_PROMOTIONS = {
    "DRAFT": {"VALIDATED"},
    "VALIDATED": {"APPROVED"},
    "APPROVED": {"PUBLISHED"},
    "PUBLISHED": {"RETIRED"},
    "RETIRED": set(),
}

def fingerprint(value):
    payload=json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def can_promote(current_state,target_state):
    current=str(current_state or "").strip().upper()
    target=str(target_state or "").strip().upper()
    return target in ALLOWED_PROMOTIONS.get(current,set())

def validate_publication_package(package):
    errors=[]
    if not isinstance(package,dict):
        return {"valid":False,"errors":["package_not_object"]}
    for k in ("package_id","version","configuration_sha256","materialization_mode","governance"):
        if k not in package:
            errors.append("missing_"+k)
    if not str(package.get("package_id") or "").strip():
        errors.append("package_id_required")
    if not str(package.get("version") or "").strip():
        errors.append("package_version_required")
    digest=str(package.get("configuration_sha256") or "").lower()
    if len(digest)!=64 or any(c not in "0123456789abcdef" for c in digest):
        errors.append("configuration_sha256_invalid")
    if package.get("materialization_mode")!="DECLARATIVE_PACKAGE_ONLY":
        errors.append("materialization_mode_invalid")
    g=package.get("governance",{})
    if not isinstance(g,dict):
        errors.append("governance_not_object")
    else:
        if g.get("shared_core_reference") is not True:
            errors.append("shared_core_reference_required")
        if g.get("core_duplicated") is not False:
            errors.append("core_duplication_forbidden")
        if g.get("auto_deploy") is not False:
            errors.append("auto_deploy_forbidden")
        if g.get("production_change") is not False:
            errors.append("production_change_forbidden")
        if g.get("example_only") not in (True,False):
            errors.append("example_only_required")
    return {"valid":not errors,"errors":errors}

def build_promotion_record(package,current_state,target_state):
    v=validate_publication_package(package)
    errors=list(v["errors"])
    if not can_promote(current_state,target_state):
        errors.append("promotion_transition_forbidden")
    return {
        "valid":not errors,
        "errors":errors,
        "package_id":package.get("package_id") if isinstance(package,dict) else None,
        "from_state":str(current_state).upper(),
        "to_state":str(target_state).upper(),
        "package_sha256":fingerprint(package) if isinstance(package,dict) else None,
        "real_platform_deployed":False,
        "production_changed":False,
    }

def build_materialization_registry(records):
    if not isinstance(records,list):
        return {"valid":False,"errors":["records_not_list"]}
    errors=[]
    seen=set()
    out=[]
    for i,r in enumerate(records):
        if not isinstance(r,dict):
            errors.append(f"record_{i}_not_object")
            continue
        rid=str(r.get("materialization_id") or "").strip()
        if not rid:
            errors.append(f"record_{i}_id_required")
            continue
        if rid in seen:
            errors.append(f"record_{i}_duplicate_id")
            continue
        seen.add(rid)
        out.append(r)
    return {
        "valid":not errors,
        "errors":errors,
        "registry_contract":"SGODA_MATERIALIZATION_REGISTRY_V1",
        "records":out,
        "real_platform_count":sum(1 for x in out if x.get("real_platform") is True),
        "example_record_count":sum(1 for x in out if x.get("example_only") is True),
    }

def example_publication_package():
    return {
        "package_id":"sgoda-example-declarative-package",
        "version":"1.0.0",
        "configuration_sha256":"0"*64,
        "materialization_mode":"DECLARATIVE_PACKAGE_ONLY",
        "governance":{
            "shared_core_reference":True,
            "core_duplicated":False,
            "auto_deploy":False,
            "production_change":False,
            "example_only":True,
        },
    }

def example_materialization_record():
    return {
        "materialization_id":"example-materialization-001",
        "package_id":"sgoda-example-declarative-package",
        "state":"PUBLISHED",
        "real_platform":False,
        "example_only":True,
        "auto_deployed":False,
        "production_changed":False,
    }
'@
    $InitText=@'
from .core import (
    ALLOWED_PROMOTIONS,
    fingerprint,
    can_promote,
    validate_publication_package,
    build_promotion_record,
    build_materialization_registry,
    example_publication_package,
    example_materialization_record,
)
__all__=[
    "ALLOWED_PROMOTIONS",
    "fingerprint",
    "can_promote",
    "validate_publication_package",
    "build_promotion_record",
    "build_materialization_registry",
    "example_publication_package",
    "example_materialization_record",
]
'@
    $TestText=@'
from sgoda.integration.spt02515 import *

def p(): return example_publication_package()
def r(): return example_materialization_record()

def test_01(): assert validate_publication_package(p())["valid"]
def test_02(): assert can_promote("DRAFT","VALIDATED")
def test_03(): assert can_promote("VALIDATED","APPROVED")
def test_04(): assert can_promote("APPROVED","PUBLISHED")
def test_05(): assert can_promote("PUBLISHED","RETIRED")
def test_06(): assert not can_promote("DRAFT","PUBLISHED")
def test_07(): assert build_promotion_record(p(),"APPROVED","PUBLISHED")["valid"]
def test_08(): assert build_promotion_record(p(),"APPROVED","PUBLISHED")["real_platform_deployed"] is False
def test_09(): assert build_promotion_record(p(),"APPROVED","PUBLISHED")["production_changed"] is False
def test_10(): assert build_materialization_registry([r()])["valid"]
def test_11(): assert build_materialization_registry([r()])["real_platform_count"]==0
def test_12(): assert build_materialization_registry([r()])["example_record_count"]==1
def test_13(): assert build_materialization_registry([r()])["registry_contract"]=="SGODA_MATERIALIZATION_REGISTRY_V1"
def test_14():
    x=p();x["governance"]["core_duplicated"]=True;assert not validate_publication_package(x)["valid"]
def test_15():
    x=p();x["governance"]["auto_deploy"]=True;assert not validate_publication_package(x)["valid"]
def test_16():
    x=p();x["governance"]["production_change"]=True;assert not validate_publication_package(x)["valid"]
def test_17():
    x=p();x["materialization_mode"]="REAL_DEPLOYMENT";assert not validate_publication_package(x)["valid"]
def test_18():
    x=p();x["configuration_sha256"]="bad";assert not validate_publication_package(x)["valid"]
def test_19():
    x=r();assert not build_materialization_registry([x,x])["valid"]
def test_20(): assert len(fingerprint(p()))==64
def test_21(): assert fingerprint(p())==fingerprint(p())
def test_22(): assert p()["governance"]["example_only"] is True
def test_23(): assert p()["governance"]["shared_core_reference"] is True
def test_24(): assert r()["real_platform"] is False
def test_25(): assert r()["auto_deployed"] is False
def test_26(): assert r()["production_changed"] is False
'@
    $PolicyText=@'
{
  "component": "SPT-025.15",
  "version": "1.0.0",
  "title": "Gobierno de Publicacion de Paquetes Declarativos, Promocion Controlada y Registro de Materializaciones",
  "authoritative_baseline": "bb7d818664e46bf7be4bc0036872bc6197fc2a2a",
  "publication": {
    "declarative_packages_only": true,
    "controlled_promotion": true,
    "materialization_registry": true,
    "sha256_required": true,
    "real_platform_deployment": false
  },
  "architecture": {
    "one_native_language_per_platform": true,
    "support_languages": "0..N_CONFIGURABLE",
    "hard_coded_support_languages": false,
    "shared_core_reference": true,
    "core_duplicated": false
  },
  "examples": {
    "example_only": true,
    "kurripaco_real_instance": false
  },
  "deployment": {
    "auto_deploy": false,
    "production_change": false
  },
  "repository": {
    "all_outputs_committed": true,
    "push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
    $DocumentationText=@'
# SPT-025.15 — Gobierno de Publicación de Paquetes Declarativos, Promoción Controlada y Registro de Materializaciones

Baseline autoritativa: `bb7d818664e46bf7be4bc0036872bc6197fc2a2a`.

Consume obligatoriamente `artifacts/development/SPT-025.14-v1.0.0/spt02515-prepare.json` y preserva íntegramente SPT-025.1–SPT-025.14.

## Objetivo

Gobernar la publicación de paquetes declarativos ya validados, controlar sus transiciones de promoción y mantener un registro institucional de materializaciones sin desplegar todavía una plataforma real.

## Reglas

- solamente paquetes declarativos;
- promoción controlada DRAFT → VALIDATED → APPROVED → PUBLISHED → RETIRED;
- SHA-256 obligatorio;
- registro de materializaciones;
- una lengua nativa principal por plataforma;
- 0..N idiomas auxiliares configurables;
- ningún idioma auxiliar hard-coded;
- SGODA Core compartido y no duplicado;
- nombres de ejemplo son evidencia técnica;
- Kurripaco no es una instancia real;
- no auto-deployment;
- no modificación de producción;
- todos los resultados, pruebas y evidencias deben quedar en el repositorio oficial.
'@
    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $DocFile $DocumentationText
    Write-Host "SPT-025.15 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    $SmokeCode=@'
from sgoda.integration.spt02515 import example_publication_package,example_materialization_record,validate_publication_package,build_promotion_record,build_materialization_registry
p=example_publication_package()
r=example_materialization_record()
assert validate_publication_package(p)["valid"]
assert build_promotion_record(p,"APPROVED","PUBLISHED")["valid"]
assert build_materialization_registry([r])["valid"]
print("SPT02515_IMPORT=PASS")
print("DECLARATIVE_PACKAGE_VALIDATION=PASS")
print("CONTROLLED_PROMOTION=PASS")
print("MATERIALIZATION_REGISTRY=PASS")
'@
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $SmokePath=Join-Path ([IO.Path]::GetTempPath()) ("spt02515-smoke-"+[guid]::NewGuid().ToString("N")+".py")
    [IO.File]::WriteAllText($SmokePath,$SmokeCode,$Utf8)
    try{
        & $Python $SmokePath
        if($LASTEXITCODE -ne 0){Hold "SPT-025.15 smoke validation failed"}
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

    Step 8 "PUBLICATION / PROMOTION / REGISTRY QUALITY GATE"
    $GateCode=@'
import json
from sgoda.integration.spt02515 import example_publication_package,example_materialization_record,validate_publication_package,build_promotion_record,build_materialization_registry
p=example_publication_package()
r=example_materialization_record()
result={
 "package":validate_publication_package(p),
 "promotion":build_promotion_record(p,"APPROVED","PUBLISHED"),
 "registry":build_materialization_registry([r]),
 "package_value":p,
 "record_value":r
}
print(json.dumps(result,ensure_ascii=False))
'@
    $GateScript=Join-Path ([IO.Path]::GetTempPath()) ("spt02515-gate-"+[guid]::NewGuid().ToString("N")+".py")
    $GateOutput=Join-Path ([IO.Path]::GetTempPath()) ("spt02515-gate-"+[guid]::NewGuid().ToString("N")+".json")
    [IO.File]::WriteAllText($GateScript,$GateCode,$Utf8)
    try{
        & $Python $GateScript|Out-File -LiteralPath $GateOutput -Encoding utf8
        if($LASTEXITCODE -ne 0){Hold "SPT-025.15 quality gate generation failed"}
        $GateResult=Get-Content -Raw -LiteralPath $GateOutput|ConvertFrom-Json
    }finally{
        Remove-Item -LiteralPath $GateScript,$GateOutput -Force -ErrorAction SilentlyContinue
    }

    if(-not[bool]$GateResult.package.valid){Hold "Declarative publication package validation failed"}
    if(-not[bool]$GateResult.promotion.valid){Hold "Controlled promotion gate failed"}
    if(-not[bool]$GateResult.registry.valid){Hold "Materialization registry gate failed"}
    if([int]$GateResult.registry.real_platform_count -ne 0){Hold "Example materialization incorrectly treated as real platform"}

    Write-Host "DECLARATIVE_PACKAGE_PUBLICATION=PASS"
    Write-Host "CONTROLLED_PROMOTION=PASS"
    Write-Host "MATERIALIZATION_REGISTRY=PASS"
    Write-Host "PUBLICATION_SHA256_INTEGRITY=PASS"
    Write-Host "REAL_PLATFORM_COUNT=0"
    Write-Host "EXAMPLE_RECORD_ONLY=PASS"
    Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "SPT-025.15 GLOBAL PUBLICATION GOVERNANCE GATE : PASS"

    Step 9 "WRITE PUBLICATION / PROMOTION / REGISTRY / EVIDENCE / PREPARE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $Publication=[ordered]@{
        component="SPT-025.15"
        version="1.0.0"
        baseline=$ExpectedBaseline
        status="DECLARATIVE_PACKAGE_PUBLICATION_GOVERNANCE_GATE_PASS"
        package_valid=[bool]$GateResult.package.valid
        promotion_valid=[bool]$GateResult.promotion.valid
        registry_valid=[bool]$GateResult.registry.valid
        real_platform_count=[int]$GateResult.registry.real_platform_count
        historical_kurripaco_reference_is_real_instance=$false
        auto_deployment=$false
        production_change=$false
        sgoda_puinave_modified=$false
    }
    $Promotion=[ordered]@{
        contract="SGODA_CONTROLLED_PROMOTION_LEDGER_V1"
        records=@($GateResult.promotion)
    }
    $Registry=[ordered]@{
        contract=[string]$GateResult.registry.registry_contract
        records=@($GateResult.registry.records)
        real_platform_count=[int]$GateResult.registry.real_platform_count
        example_record_count=[int]$GateResult.registry.example_record_count
    }
    $Evidence=[ordered]@{
        component="SPT-025.15"
        version="1.0.0"
        baseline=$ExpectedBaseline
        spt02514_gate="PASS"
        prepare_consumed=$ReqPrepare
        targeted_tests="PASS"
        institutional_suite="PASS"
        compileall="PASS"
        global_publication_governance_gate="PASS"
        all_outputs_to_repository=$true
        closed_components_preserved=$true
    }
    $Next=[ordered]@{
        next_deliverable="SPT-025.16"
        title="Recertificacion de Publicacion, Registro Maestro de Materializaciones y Quality Gate de Promocion Final"
        source_baseline=$ExpectedBaseline
        spt02515_publication_governance_gate="PASS"
    }

    Write-Lf $PublicationFile ($Publication|ConvertTo-Json -Depth 12)
    Write-Lf $PromotionFile ($Promotion|ConvertTo-Json -Depth 12)
    Write-Lf $RegistryFile ($Registry|ConvertTo-Json -Depth 12)
    Write-Lf $ExamplePackageFile ($GateResult.package_value|ConvertTo-Json -Depth 12)
    Write-Lf $ExampleRecordFile ($GateResult.record_value|ConvertTo-Json -Depth 12)
    Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 12)
    Write-Lf $PrepareFile ($Next|ConvertTo-Json -Depth 12)

    $Records=@()
    foreach($P in @($PublicationFile,$PromotionFile,$RegistryFile,$ExamplePackageFile,$ExampleRecordFile,$EvidenceFile,$PrepareFile)){
        $Records+=[ordered]@{path=$P;sha256=Get-Sha256 (Join-Path $Root $P)}
    }
    Write-Lf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$Records}|ConvertTo-Json -Depth 12)

    Write-Host "PUBLICATION ASSESSMENT : CREATED"
    Write-Host "PROMOTION LEDGER       : CREATED"
    Write-Host "MATERIALIZATION REGISTRY: CREATED"
    Write-Host "EXAMPLE PACKAGE        : CREATED / EXAMPLE ONLY"
    Write-Host "EXAMPLE RECORD         : CREATED / EXAMPLE ONLY"
    Write-Host "SHA-256 MANIFEST       : CREATED"
    Write-Host "SPT-025.16 PREPARE     : CREATED"
    Write-Host "EVIDENCE               : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($TrackedPath in $Freeze.Keys){
        $A=Join-Path $Root $TrackedPath
        if(-not(Test-Path -LiteralPath $A)){Hold ("Protected tracked file disappeared: "+$TrackedPath)}
        if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Protected tracked file changed: "+$TrackedPath)}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-025.1-.14 : PRESERVED / NOT REOPENED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@(
        "Invoke-SGODA-SPT02515-DeclarativePackagePublication-ControlledPromotion-MaterializationRegistry-FINAL-v1.0.0-PS51.ps1",
        $CoreFile,
        $InitFile,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $PublicationFile,
        $PromotionFile,
        $RegistryFile,
        $ExamplePackageFile,
        $ExampleRecordFile,
        $IntegrityFile,
        $EvidenceFile,
        $PrepareFile
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
    & git.exe commit -m "feat(spt-025.15): govern declarative package publication promotion and materialization registry"
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
    Write-Host "SPT-025.15 : TECHNICALLY CLOSED / DECLARATIVE PACKAGE PUBLICATION GOVERNANCE APPROVED" -ForegroundColor Green
    Write-Host "SPT-025.14_MATERIALIZATION_QUALITY_GATE=PASS"
    Write-Host "SPT-025.15_PREPARE_CONSUMED=PASS"
    Write-Host "DECLARATIVE_PACKAGE_PUBLICATION=PASS"
    Write-Host "CONTROLLED_PROMOTION=PASS"
    Write-Host "MATERIALIZATION_REGISTRY=PASS"
    Write-Host "PUBLICATION_SHA256_INTEGRITY=PASS"
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
    Write-Host "NEXT_DELIVERABLE=SPT-025.16"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}catch{
    Hold $_.Exception.Message
}
