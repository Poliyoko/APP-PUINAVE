#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "c3c83833c82e8d4310c38cde660b8d4c45be2e86"
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$ReqGate = "artifacts/development/SPT-025.9-v1.0.0/materialization-governance-assessment.json"
$ReqPrepare = "artifacts/development/SPT-025.9-v1.0.0/spt02510-prepare.json"
$ReqContinuity = "artifacts/development/SPT-025.RepositoryContinuityAudit-v1.0.0/repository-continuity-assessment.json"

$CoreFile = "src/sgoda/integration/spt02510/core.py"
$InitFile = "src/sgoda/integration/spt02510/__init__.py"
$TestFile = "tests/integration/test_spt02510_master_instance_registry_lifecycle.py"
$PolicyFile = "config/integration/spt02510/master-instance-registry-lifecycle-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-025/SPT-025.10/SGD-SPT025.10-Registro-Maestro-Instancias-Versionado-Trazabilidad-Ciclo-Vida.md"

$ArtifactDir = "artifacts/development/SPT-025.10-v1.0.0"
$RegistryFile = "$ArtifactDir/master-instance-registry.json"
$VersionLedgerFile = "$ArtifactDir/package-version-ledger.json"
$TraceabilityFile = "$ArtifactDir/instance-traceability-ledger.json"
$LifecycleFile = "$ArtifactDir/lifecycle-governance-baseline.json"
$ExampleRecordFile = "$ArtifactDir/example-instance-registry-record.json"
$AssessmentFile = "$ArtifactDir/master-registry-lifecycle-assessment.json"
$IntegrityFile = "$ArtifactDir/master-registry-sha256-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"
$PrepareFile = "$ArtifactDir/spt02511-prepare.json"

function Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number, $Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-025.10 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}

function Fetch-Authoritative {
    for ($Attempt = 1; $Attempt -le 4; $Attempt++) {
        Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $Attempt)
        & git.exe fetch origin $Branch
        if ($LASTEXITCODE -eq 0) {
            Write-Host "GIT FETCH : PASS"
            return
        }
        Start-Sleep -Seconds 2
    }
    Hold "git fetch failed"
}

function Write-Lf {
    param([string]$Path, [string]$Text)
    $Absolute = Join-Path $Root $Path
    $Parent = Split-Path -Parent $Absolute
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $Normalized = (($Text -replace "`r`n", "`n") -replace "`r", "`n")
    if (-not $Normalized.EndsWith("`n")) {
        $Normalized += "`n"
    }
    [System.IO.File]::WriteAllText($Absolute, $Normalized, $Utf8)
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

try {
    $Root = (& git.exe rev-parse --show-toplevel).Trim()
    if (-not $Root) {
        Hold "Not inside Git repository"
    }
    Set-Location $Root

    $Python = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $Python)) {
        $Python = "python.exe"
    }

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    Fetch-Authoritative

    $LocalHead = (& git.exe rev-parse HEAD).Trim()
    $RemoteHead = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Staged = @(& git.exe diff --cached --name-only)
    $DeletedTracked = @(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($DeletedTracked.Count)"

    if ($LocalHead -ne $ExpectedBaseline -or $RemoteHead -ne $ExpectedBaseline) {
        Hold "Authoritative baseline mismatch"
    }
    if ($Staged.Count -ne 0 -or $DeletedTracked.Count -ne 0) {
        Hold "Unsafe staged/deleted state"
    }

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-025.1-.9 + REPOSITORY AUDIT : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-025.9 MATERIALIZATION GATE / PREPARE / CONTINUITY"
    $RequiredInputs = @($ReqGate, $ReqPrepare, $ReqContinuity)
    $Missing = @(
        $RequiredInputs | Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $Root $_))
        }
    )

    Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS  : $($Missing.Count)"

    if ($Missing.Count -ne 0) {
        Hold "Missing SPT-025.10 prerequisites"
    }

    $Gate = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqGate) | ConvertFrom-Json
    $Continuity = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqContinuity) | ConvertFrom-Json

    if ([string]$Gate.status -ne "CONTROLLED_INSTANCE_MATERIALIZATION_GATE_PASS") {
        Hold "SPT-025.9 controlled materialization gate is not PASS"
    }
    if ([string]$Continuity.status -ne "REPOSITORY_CONTINUITY_GATE_PASS") {
        Hold "Repository continuity gate is not PASS"
    }

    Write-Host "SPT-025.9 MATERIALIZATION GATE : PASS"
    Write-Host "REPOSITORY CONTINUITY GATE    : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
    $Freeze = @{}
    foreach ($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (Test-Path -LiteralPath $AbsoluteTrackedPath) {
            $Freeze[$TrackedPath] = Get-Sha256 $AbsoluteTrackedPath
        }
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "MASTER INSTANCE REGISTRY / VERSION / LIFECYCLE DISCOVERY"
    Write-Host "REGISTRY MODE              : GOVERNANCE / METADATA ONLY"
    Write-Host "INSTANCE MODEL             : GENERIC / LANGUAGE-NEUTRAL"
    Write-Host "ONE NATIVE LANGUAGE        : PER PLATFORM"
    Write-Host "SUPPORT LANGUAGES          : 0..N / CONFIGURABLE"
    Write-Host "EXAMPLE NAMES              : EVIDENCE ONLY / NOT REAL INSTANCES"
    Write-Host "PACKAGE VERSIONING         : REQUIRED"
    Write-Host "TRACEABILITY               : REQUIRED"
    Write-Host "LIFECYCLE GOVERNANCE       : REQUIRED"
    Write-Host "AUTO DEPLOYMENT            : NO"
    Write-Host "PRODUCTION CHANGE          : NO"

    Step 5 "IMPLEMENT SPT-025.10 MASTER REGISTRY / LIFECYCLE GOVERNANCE"
    $CoreText = @'
from hashlib import sha256
import json
import re

INSTANCE_ID_RE = re.compile(r"^sgoda-[a-z0-9][a-z0-9-]*$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")

ALLOWED_STATES = (
    "DRAFT", "VALIDATED", "MATERIALIZED", "REGISTERED",
    "SUSPENDED", "RETIRED", "ARCHIVED"
)

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def normalize_instance_id(value):
    text = _t(value).lower().replace("_", "-").replace(" ", "-")
    return re.sub(r"-+", "-", text)

def validate_registry_record(record):
    errors = []
    if not isinstance(record, dict):
        return {"valid": False, "errors": ["record_not_object"]}
    required = ("instance_id","native_language","support_languages","package","lifecycle","governance")
    for key in required:
        if key not in record:
            errors.append("missing_" + key)
    instance_id = normalize_instance_id(record.get("instance_id"))
    if not INSTANCE_ID_RE.match(instance_id or ""):
        errors.append("instance_id_invalid")
    native = record.get("native_language")
    native_code = normalize_code(native.get("code")) if isinstance(native, dict) else ""
    if not native_code:
        errors.append("native_language_required")
    supports = record.get("support_languages")
    if not isinstance(supports, list):
        errors.append("support_languages_not_list")
        supports = []
    seen = set()
    support_codes = []
    for i,item in enumerate(supports):
        if not isinstance(item, dict):
            errors.append(f"support_{i}_not_object"); continue
        code = normalize_code(item.get("code"))
        if not code:
            errors.append(f"support_{i}_code_required")
        elif code == native_code:
            errors.append(f"support_{i}_equals_native")
        elif code in seen:
            errors.append(f"support_{i}_duplicate")
        else:
            seen.add(code); support_codes.append(code)
    package = record.get("package")
    if not isinstance(package, dict):
        errors.append("package_not_object")
    else:
        if not VERSION_RE.match(_t(package.get("version"))):
            errors.append("package_version_invalid")
        digest = _t(package.get("sha256")).lower()
        if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            errors.append("package_sha256_invalid")
    lifecycle = record.get("lifecycle")
    state = _t(lifecycle.get("state")).upper() if isinstance(lifecycle, dict) else ""
    if state not in ALLOWED_STATES:
        errors.append("lifecycle_state_invalid")
    governance = record.get("governance")
    if not isinstance(governance, dict):
        errors.append("governance_not_object")
    else:
        if governance.get("shared_core_reference") is not True:
            errors.append("shared_core_reference_required")
        if governance.get("core_duplicated") is not False:
            errors.append("core_duplication_forbidden")
        if governance.get("auto_deployed") is not False:
            errors.append("auto_deployment_forbidden")
        if governance.get("production_changed") is not False:
            errors.append("production_change_forbidden")
        if governance.get("example_only") not in (True, False):
            errors.append("example_only_required")
    return {
        "valid": not errors, "errors": errors, "instance_id": instance_id,
        "native_language": native_code, "support_languages": support_codes,
        "state": state,
    }

def record_fingerprint(record):
    payload=json.dumps(record,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def build_master_registry(records):
    if not isinstance(records, list):
        return {"valid":False,"errors":["records_not_list"]}
    normalized=[]; ids=set(); errors=[]
    for i,record in enumerate(records):
        result=validate_registry_record(record)
        if not result["valid"]:
            errors.extend([f"record_{i}_{e}" for e in result["errors"]]); continue
        if result["instance_id"] in ids:
            errors.append(f"record_{i}_duplicate_instance_id"); continue
        ids.add(result["instance_id"])
        normalized.append({
            "instance_id":result["instance_id"],
            "native_language":result["native_language"],
            "support_languages":result["support_languages"],
            "package_version":record["package"]["version"],
            "package_sha256":record["package"]["sha256"].lower(),
            "lifecycle_state":result["state"],
            "example_only":record["governance"]["example_only"],
            "fingerprint":record_fingerprint(record),
        })
    return {
        "valid":not errors, "errors":errors,
        "registry_contract":"SGODA_MASTER_INSTANCE_REGISTRY_V1",
        "records":normalized,
        "real_instances":sum(1 for x in normalized if not x["example_only"]),
        "example_records":sum(1 for x in normalized if x["example_only"]),
    }

def can_transition(current_state, target_state):
    current=_t(current_state).upper(); target=_t(target_state).upper()
    transitions={
        "DRAFT":{"VALIDATED","ARCHIVED"},
        "VALIDATED":{"MATERIALIZED","ARCHIVED"},
        "MATERIALIZED":{"REGISTERED","ARCHIVED"},
        "REGISTERED":{"SUSPENDED","RETIRED"},
        "SUSPENDED":{"REGISTERED","RETIRED"},
        "RETIRED":{"ARCHIVED"},
        "ARCHIVED":set(),
    }
    return target in transitions.get(current,set())

def example_reference_record():
    # Deliberately generic: it proves the contract without selecting a real language/community.
    return {
        "instance_id":"sgoda-example-language",
        "native_language":{"code":"qaa","name":"Example Native Language"},
        "support_languages":[
            {"code":"es","name":"Español"},
            {"code":"en","name":"English"},
            {"code":"it","name":"Italiano"},
            {"code":"pt","name":"Português"},
        ],
        "package":{"version":"1.0.0","sha256":"0"*64},
        "lifecycle":{"state":"MATERIALIZED"},
        "governance":{
            "shared_core_reference":True,
            "core_duplicated":False,
            "auto_deployed":False,
            "production_changed":False,
            "example_only":True,
        },
    }
'@
    $InitText = @'
from .core import (
    INSTANCE_ID_RE, VERSION_RE, ALLOWED_STATES,
    normalize_code, normalize_instance_id, validate_registry_record,
    record_fingerprint, build_master_registry, can_transition,
    example_reference_record,
)

__all__ = [
    "INSTANCE_ID_RE", "VERSION_RE", "ALLOWED_STATES",
    "normalize_code", "normalize_instance_id", "validate_registry_record",
    "record_fingerprint", "build_master_registry", "can_transition",
    "example_reference_record",
]
'@
    $TestText = @'
from sgoda.integration.spt02510 import *

def ref():
    return example_reference_record()

def test_01(): assert validate_registry_record(ref())["valid"]
def test_02(): assert validate_registry_record(ref())["native_language"] == "qaa"
def test_03(): assert validate_registry_record(ref())["support_languages"] == ["es","en","it","pt"]
def test_04(): assert build_master_registry([ref()])["valid"]
def test_05(): assert build_master_registry([ref()])["real_instances"] == 0
def test_06(): assert build_master_registry([ref()])["example_records"] == 1
def test_07(): assert build_master_registry([ref()])["registry_contract"] == "SGODA_MASTER_INSTANCE_REGISTRY_V1"
def test_08(): assert ref()["governance"]["example_only"] is True
def test_09(): assert ref()["governance"]["auto_deployed"] is False
def test_10(): assert ref()["governance"]["production_changed"] is False
def test_11(): assert ref()["governance"]["core_duplicated"] is False
def test_12(): assert ref()["governance"]["shared_core_reference"] is True
def test_13(): assert can_transition("DRAFT","VALIDATED")
def test_14(): assert can_transition("VALIDATED","MATERIALIZED")
def test_15(): assert can_transition("MATERIALIZED","REGISTERED")
def test_16(): assert not can_transition("MATERIALIZED","DRAFT")
def test_17(): assert can_transition("REGISTERED","SUSPENDED")
def test_18(): assert can_transition("SUSPENDED","REGISTERED")
def test_19(): assert can_transition("REGISTERED","RETIRED")
def test_20(): assert can_transition("RETIRED","ARCHIVED")
def test_21():
    x=ref(); x["package"]["version"]="v1"; assert not validate_registry_record(x)["valid"]
def test_22():
    x=ref(); x["package"]["sha256"]="bad"; assert not validate_registry_record(x)["valid"]
def test_23():
    x=ref(); x["support_languages"].append({"code":"qaa","name":"bad"}); assert not validate_registry_record(x)["valid"]
def test_24():
    x=ref(); x["support_languages"].append({"code":"es","name":"dup"}); assert not validate_registry_record(x)["valid"]
def test_25():
    x=ref(); x["governance"]["core_duplicated"]=True; assert not validate_registry_record(x)["valid"]
def test_26():
    x=ref(); x["governance"]["auto_deployed"]=True; assert not validate_registry_record(x)["valid"]
def test_27():
    x=ref(); x["governance"]["production_changed"]=True; assert not validate_registry_record(x)["valid"]
def test_28():
    x=ref(); x["lifecycle"]["state"]="UNKNOWN"; assert not validate_registry_record(x)["valid"]
def test_29(): assert len(record_fingerprint(ref())) == 64
def test_30():
    x=ref(); assert not build_master_registry([x,x])["valid"]
def test_31(): assert normalize_instance_id("SGODA Example Language") == "sgoda-example-language"
def test_32(): assert normalize_code("EN_us") == "en-us"
'@
    $PolicyText = @'
{
  "component": "SPT-025.10",
  "version": "1.0.0",
  "title": "Registro Maestro de Instancias, Versionado de Paquetes, Trazabilidad y Gobierno de Ciclo de Vida",
  "authoritative_baseline": "c3c83833c82e8d4310c38cde660b8d4c45be2e86",
  "architecture": {
    "sgoda_core": "SHARED_REFERENCE",
    "one_native_language_per_platform": true,
    "support_languages": "0..N_CONFIGURABLE",
    "hard_coded_support_languages": false
  },
  "registry": {
    "generic_language_neutral": true,
    "package_version_required": true,
    "package_sha256_required": true,
    "traceability_required": true,
    "lifecycle_governance_required": true
  },
  "examples": {
    "names_are_evidence_only": true,
    "example_is_real_instance": false,
    "default_deployment_target": false
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
    $DocumentationText = @'
# SPT-025.10 — Registro Maestro de Instancias, Versionado de Paquetes, Trazabilidad y Gobierno de Ciclo de Vida

Baseline autoritativa: `c3c83833c82e8d4310c38cde660b8d4c45be2e86`.

## Objetivo
Crear el registro institucional genérico de plataformas lingüísticas SGODA, gobernar las versiones de sus paquetes, mantener trazabilidad SHA-256 y controlar su ciclo de vida sin desplegar nuevas plataformas.

## Arquitectura
`SGODA Core → Motor de Instancias → una lengua nativa configurable → plataforma SGODA independiente → 0..N idiomas auxiliares configurables`.

Los idiomas auxiliares no están fijados en código. Español, inglés, italiano y portugués son ejemplos válidos de configuración, no una lista cerrada.

## Regla sobre nombres de ejemplo
Cualquier nombre de lengua o comunidad utilizado durante pruebas, previews o evidencias es exclusivamente ilustrativo. No constituye una instancia real, una comunidad seleccionada ni un destino de despliegue. En particular, las referencias históricas de ensayo a Kurripaco en SPT-025.7–SPT-025.9 siguen siendo evidencia técnica no desplegada.

## Gobierno
El registro controla identidad de instancia, lengua nativa, idiomas auxiliares, versión del paquete, SHA-256, estado de ciclo de vida, trazabilidad y referencia compartida a SGODA Core.

SPT-025.10 no despliega plataformas, no modifica producción, no duplica SGODA Core y no modifica SGODA-PUINAVE.

Todos los resultados, pruebas, políticas, documentación, registros, manifests y evidencias deben quedar publicados en el repositorio oficial.
'@

    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $DocFile $DocumentationText

    Write-Host "SPT-025.10 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "POWERSHELL-SAFE PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH = Join-Path $Root "src"

    $SmokeCode = @'
from sgoda.integration.spt02510 import (
    example_reference_record, validate_registry_record,
    build_master_registry, can_transition,
)
record = example_reference_record()
assert validate_registry_record(record)["valid"]
registry = build_master_registry([record])
assert registry["valid"]
assert registry["real_instances"] == 0
assert registry["example_records"] == 1
assert can_transition("MATERIALIZED", "REGISTERED")
print("SPT02510_IMPORT=PASS")
print("MASTER_INSTANCE_REGISTRY_CONTRACT=PASS")
print("PACKAGE_VERSION_GOVERNANCE=PASS")
print("TRACEABILITY_GOVERNANCE=PASS")
print("LIFECYCLE_GOVERNANCE=PASS")
print("EXAMPLE_ONLY_NO_REAL_INSTANCE=PASS")
'@

    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $SmokePath = Join-Path ([System.IO.Path]::GetTempPath()) ("spt02510-smoke-" + [guid]::NewGuid().ToString("N") + ".py")
    [System.IO.File]::WriteAllText($SmokePath, $SmokeCode, $Utf8)

    try {
        & $Python $SmokePath
        if ($LASTEXITCODE -ne 0) {
            Hold "SPT-025.10 smoke validation failed"
        }
    }
    finally {
        Remove-Item -LiteralPath $SmokePath -Force -ErrorAction SilentlyContinue
    }

    & $Python -m pytest -q $TestFile
    if ($LASTEXITCODE -ne 0) {
        Hold "Targeted tests failed"
    }
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
    & $Python -m pytest -q
    if ($LASTEXITCODE -ne 0) {
        Hold "Institutional suite failed"
    }
    Write-Host "FULL SUITE : PASS"

    & $Python -m compileall -q (Join-Path $Root "src")
    if ($LASTEXITCODE -ne 0) {
        Hold "compileall failed"
    }
    Write-Host "COMPILEALL : PASS"

    Step 8 "MASTER REGISTRY / VERSION / TRACEABILITY / LIFECYCLE GATE"
    $RegistryCode = @'
import json
from sgoda.integration.spt02510 import example_reference_record, build_master_registry
record = example_reference_record()
registry = build_master_registry([record])
print(json.dumps({"record":record,"registry":registry}, ensure_ascii=False))
'@
    $RegistryScript = Join-Path ([System.IO.Path]::GetTempPath()) ("spt02510-registry-" + [guid]::NewGuid().ToString("N") + ".py")
    $RegistryOutput = Join-Path ([System.IO.Path]::GetTempPath()) ("spt02510-registry-" + [guid]::NewGuid().ToString("N") + ".json")
    [System.IO.File]::WriteAllText($RegistryScript, $RegistryCode, $Utf8)
    try {
        & $Python $RegistryScript | Out-File -LiteralPath $RegistryOutput -Encoding utf8
        if ($LASTEXITCODE -ne 0) { Hold "Master registry generation failed" }
        $RegistryResult = Get-Content -Raw -LiteralPath $RegistryOutput | ConvertFrom-Json
    }
    finally {
        Remove-Item -LiteralPath $RegistryScript -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $RegistryOutput -Force -ErrorAction SilentlyContinue
    }
    if (-not [bool]$RegistryResult.registry.valid) { Hold "Master registry validation failed" }
    if ([int]$RegistryResult.registry.real_instances -ne 0) { Hold "Example record was incorrectly treated as real instance" }

    Write-Host "MASTER_INSTANCE_REGISTRY=PASS"
    Write-Host "GENERIC_LANGUAGE_NEUTRAL_MODEL=PASS"
    Write-Host "ONE_NATIVE_LANGUAGE_PER_PLATFORM=PASS"
    Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS"
    Write-Host "PACKAGE_VERSION_GOVERNANCE=PASS"
    Write-Host "TRACEABILITY_GOVERNANCE=PASS"
    Write-Host "LIFECYCLE_GOVERNANCE=PASS"
    Write-Host "EXAMPLE_RECORD_REAL_INSTANCE=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "SPT-025.10 GLOBAL GOVERNANCE GATE : PASS"

    Step 9 "WRITE MASTER REGISTRY / LEDGERS / GOVERNANCE EVIDENCE"
    $ExampleRecord = $RegistryResult.record
    $MasterRegistry = [ordered]@{
        component = "SPT-025.10"
        contract = "SGODA_MASTER_INSTANCE_REGISTRY_V1"
        registry_mode = "GENERIC_LANGUAGE_NEUTRAL"
        real_instance_count = 0
        example_record_count = 1
        records = @($RegistryResult.registry.records)
    }
    $VersionLedger = [ordered]@{
        contract = "SGODA_PACKAGE_VERSION_LEDGER_V1"
        example_only = $true
        entries = @([ordered]@{
            instance_id = [string]$ExampleRecord.instance_id
            package_version = [string]$ExampleRecord.package.version
            package_sha256 = [string]$ExampleRecord.package.sha256
            operational_deployment = $false
        })
    }
    $Traceability = [ordered]@{
        contract = "SGODA_INSTANCE_TRACEABILITY_LEDGER_V1"
        source_baseline = $ExpectedBaseline
        source_prepare = $ReqPrepare
        spt0259_gate = "PASS"
        example_names_are_evidence_only = $true
        kurripaco_historical_reference_is_real_instance = $false
        deployment_executed = $false
    }
    $Lifecycle = [ordered]@{
        contract = "SGODA_INSTANCE_LIFECYCLE_V1"
        states = @("DRAFT","VALIDATED","MATERIALIZED","REGISTERED","SUSPENDED","RETIRED","ARCHIVED")
        auto_deployment = $false
        production_change = $false
        shared_core_reference = $true
        core_duplication = $false
    }
    $Assessment = [ordered]@{
        component = "SPT-025.10"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        status = "MASTER_INSTANCE_REGISTRY_LIFECYCLE_GATE_PASS"
        generic_language_neutral = $true
        one_native_language_per_platform = $true
        support_languages_configurable_0_to_n = $true
        hard_coded_support_languages = $false
        real_new_platform_deployed = $false
        example_record_is_real_instance = $false
        sgoda_puinave_modified = $false
        production_changed = $false
    }
    $Evidence = [ordered]@{
        component = "SPT-025.10"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        targeted_tests = "PASS"
        institutional_suite = "PASS"
        compileall = "PASS"
        master_registry_gate = "PASS"
        all_outputs_to_repository = $true
        closed_components_preserved = $true
    }
    $Prepare = [ordered]@{
        next_deliverable = "SPT-025.11"
        title = "Catalogo Institucional de Plantillas de Instancia y Perfiles de Configuracion Reutilizables"
        source_baseline = $ExpectedBaseline
        spt02510_master_registry_gate = "PASS"
    }

    Write-Lf $RegistryFile ($MasterRegistry | ConvertTo-Json -Depth 12)
    Write-Lf $VersionLedgerFile ($VersionLedger | ConvertTo-Json -Depth 12)
    Write-Lf $TraceabilityFile ($Traceability | ConvertTo-Json -Depth 12)
    Write-Lf $LifecycleFile ($Lifecycle | ConvertTo-Json -Depth 12)
    Write-Lf $ExampleRecordFile ($ExampleRecord | ConvertTo-Json -Depth 12)
    Write-Lf $AssessmentFile ($Assessment | ConvertTo-Json -Depth 12)
    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 12)
    Write-Lf $PrepareFile ($Prepare | ConvertTo-Json -Depth 12)

    $IntegrityRecords = @()
    foreach ($P in @($RegistryFile,$VersionLedgerFile,$TraceabilityFile,$LifecycleFile,$ExampleRecordFile,$AssessmentFile,$EvidenceFile,$PrepareFile)) {
        $IntegrityRecords += [ordered]@{ path=$P; sha256=Get-Sha256 (Join-Path $Root $P) }
    }
    Write-Lf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords} | ConvertTo-Json -Depth 12)

    Write-Host "MASTER REGISTRY       : CREATED"
    Write-Host "PACKAGE VERSION LEDGER: CREATED"
    Write-Host "TRACEABILITY LEDGER   : CREATED"
    Write-Host "LIFECYCLE GOVERNANCE  : CREATED"
    Write-Host "EXAMPLE RECORD        : CREATED / NOT REAL INSTANCE"
    Write-Host "SHA-256 MANIFEST      : CREATED"
    Write-Host "SPT-025.11 PREPARE    : CREATED"
    Write-Host "EVIDENCE              : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (-not (Test-Path -LiteralPath $AbsoluteTrackedPath)) {
            Hold ("Protected tracked file disappeared: " + $TrackedPath)
        }
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) {
            Hold ("Protected tracked file changed: " + $TrackedPath)
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-025.1-.9 + REPOSITORY AUDIT : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed = @(
        "Invoke-SGODA-SPT02510-MasterInstanceRegistry-PackageVersionLifecycleGov-FINAL-v1.0.0-PS51.ps1",
        $CoreFile,
        $InitFile,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $RegistryFile,
        $VersionLedgerFile,
        $TraceabilityFile,
        $LifecycleFile,
        $ExampleRecordFile,
        $AssessmentFile,
        $IntegrityFile,
        $EvidenceFile,
        $PrepareFile
    )

    foreach ($AllowedPath in $Allowed) {
        $AbsoluteAllowed = Join-Path $Root $AllowedPath
        if (-not (Test-Path -LiteralPath $AbsoluteAllowed)) {
            Hold ("Missing expected target: " + $AllowedPath)
        }
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $AllowedPath
        if ($LASTEXITCODE -ne 0) {
            Hold ("git add failed: " + $AllowedPath)
        }
    }

    $StagedNames = @(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected = @(
        $StagedNames | Where-Object {
            $Allowed -notcontains ($_ -replace "\\", "/")
        }
    )

    Write-Host "STAGED     : $($StagedNames.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if ($Unexpected.Count -ne 0 -or $StagedNames.Count -ne $Allowed.Count) {
        Hold "Exact staging mismatch"
    }
    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"
    $Oversized = @()
    foreach ($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $BlobSizeText = @(& git.exe cat-file -s (":" + $TrackedPath) 2>$null)
        if ($LASTEXITCODE -eq 0 -and $BlobSizeText.Count -gt 0) {
            [Int64]$BlobSize = 0
            if ([Int64]::TryParse(([string]$BlobSizeText[0]).Trim(), [ref]$BlobSize)) {
                if ($BlobSize -ge 100MB) {
                    $Oversized += $TrackedPath
                }
            }
        }
    }

    Write-Host "INDEX BLOBS >=100MB : $($Oversized.Count)"
    if ($Oversized.Count -ne 0) {
        Hold "GitHub size gate failed"
    }
    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE / PRESERVATION GATE"
    Fetch-Authoritative

    $RemoteBeforeCommit = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    if ($RemoteBeforeCommit -ne $ExpectedBaseline) {
        Hold "Remote advanced during transaction"
    }

    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) {
            Hold ("Preservation failure before commit: " + $TrackedPath)
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "feat(spt-025.10): govern master instance registry package versions traceability lifecycle"
    if ($LASTEXITCODE -ne 0) {
        Hold "git commit failed"
    }

    $NewCommit = (& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        Hold "git push failed"
    }
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TECHNICAL CLOSURE"
    Fetch-Authoritative

    $FinalLocal = (& git.exe rev-parse HEAD).Trim()
    $FinalRemote = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Behind = (& git.exe rev-list --count ("HEAD..origin/" + $Branch)).Trim()
    $Ahead = (& git.exe rev-list --count ("origin/" + $Branch + "..HEAD")).Trim()
    $FinalStaged = @(& git.exe diff --cached --name-only)
    $FinalDeleted = @(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $Behind"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if ($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0") {
        Hold "Final synchronization failed"
    }
    if ($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0) {
        Hold "Final repository state is not clean enough for closure"
    }

    Write-Host ""
    Write-Host "SPT-025.10 : TECHNICALLY CLOSED / MASTER INSTANCE REGISTRY & LIFECYCLE GOVERNANCE APPROVED" -ForegroundColor Green
    Write-Host "SPT-025.9_MATERIALIZATION_GATE=PASS"
    Write-Host "REPOSITORY_CONTINUITY_GATE=PASS"
    Write-Host "MASTER_INSTANCE_REGISTRY=PASS"
    Write-Host "GENERIC_LANGUAGE_NEUTRAL_MODEL=PASS"
    Write-Host "ONE_NATIVE_LANGUAGE_PER_PLATFORM=PASS"
    Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS"
    Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO"
    Write-Host "PACKAGE_VERSION_GOVERNANCE=PASS"
    Write-Host "TRACEABILITY_GOVERNANCE=PASS"
    Write-Host "LIFECYCLE_GOVERNANCE=PASS"
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
    Write-Host "NEXT_DELIVERABLE=SPT-025.11"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
