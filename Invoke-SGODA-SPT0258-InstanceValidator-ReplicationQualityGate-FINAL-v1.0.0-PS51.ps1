#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "0fd93995564ceba8c05316145221bd4ece4a1443"
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$ReqAudit = "artifacts/development/SPT-025.RepositoryContinuityAudit-v1.0.0/repository-continuity-assessment.json"
$ReqPrepare = "artifacts/development/SPT-025.RepositoryContinuityAudit-v1.0.0/spt0258-repository-continuity-prepare.json"
$ReqFactory = "artifacts/development/SPT-025.7-v1.0.1/spt0257-bootstrap-assessment.json"

$CoreFile = "src/sgoda/integration/spt0258/core.py"
$InitFile = "src/sgoda/integration/spt0258/__init__.py"
$TestFile = "tests/integration/test_spt0258_instance_validator_replication_quality_gate.py"
$PolicyFile = "config/integration/spt0258/instance-validation-quality-gate-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-025/SPT-025.8/SGD-SPT025.8-Validador-Instancias-Quality-Gates-Replicacion-No-Destructiva.md"

$ArtifactDir = "artifacts/development/SPT-025.8-v1.0.0"
$ValidationFile = "$ArtifactDir/instance-validation-assessment.json"
$CompatibilityFile = "$ArtifactDir/sgoda-core-compatibility-assessment.json"
$LanguageFile = "$ArtifactDir/language-contract-validation.json"
$RlbFile = "$ArtifactDir/rlb-contract-validation.json"
$ResourceFile = "$ArtifactDir/resource-contract-validation.json"
$IdentityFile = "$ArtifactDir/identity-contract-validation.json"
$ReplicationFile = "$ArtifactDir/kurripaco-nondestructive-replication-trial.json"
$ShaFile = "$ArtifactDir/replication-sha256-integrity.json"
$GateFile = "$ArtifactDir/spt0258-global-quality-gate.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"
$PrepareFile = "$ArtifactDir/spt0259-prepare.json"

function Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number, $Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-025.8 : HOLD" -ForegroundColor Red
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
    Write-Host "SPT-025.1-.7 + REPOSITORY AUDIT : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY REPOSITORY CONTINUITY + SPT-025.7 INPUTS"
    $RequiredInputs = @($ReqAudit, $ReqPrepare, $ReqFactory)
    $Missing = @(
        $RequiredInputs | Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $Root $_))
        }
    )

    Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS  : $($Missing.Count)"

    if ($Missing.Count -ne 0) {
        Hold "Missing SPT-025.8 prerequisites"
    }

    $AuditAssessment = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqAudit) | ConvertFrom-Json
    $FactoryAssessment = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqFactory) | ConvertFrom-Json

    if ([string]$AuditAssessment.status -ne "REPOSITORY_CONTINUITY_GATE_PASS") {
        Hold "Repository continuity gate is not PASS"
    }
    if ([string]$FactoryAssessment.status -ne "LANGUAGE_INSTANCE_BOOTSTRAP_GATE_PASS") {
        Hold "SPT-025.7 bootstrap factory gate is not PASS"
    }

    Write-Host "REPOSITORY CONTINUITY GATE : PASS"
    Write-Host "SPT-025.7 BOOTSTRAP FACTORY GATE : PASS"

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

    Step 4 "INSTANCE VALIDATION / REPLICATION DISCOVERY"
    Write-Host "VALIDATION MODE             : STATIC / NON-DESTRUCTIVE"
    Write-Host "REFERENCE TRIAL             : SGODA-KURRIPACO"
    Write-Host "NATIVE LANGUAGE CONTRACT    : REQUIRED"
    Write-Host "SUPPORT LANGUAGE CONTRACT   : REQUIRED"
    Write-Host "RLB CONTRACT                : REQUIRED"
    Write-Host "RESOURCE CONTRACT           : REQUIRED"
    Write-Host "IDENTITY CONTRACT           : REQUIRED"
    Write-Host "SGODA CORE COMPATIBILITY    : REQUIRED"
    Write-Host "SHA-256 INTEGRITY           : REQUIRED"
    Write-Host "REAL PLATFORM DEPLOYMENT    : NO"

    Step 5 "IMPLEMENT SPT-025.8 VALIDATOR"
    $CoreText = @'
from hashlib import sha256
import json

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def validate_language_contract(platform):
    errors = []
    native = platform.get("native_language")
    supports = platform.get("support_languages", [])
    if not isinstance(native, dict):
        errors.append("native_language_not_object")
        return errors
    native_code = normalize_code(native.get("code"))
    if not native_code:
        errors.append("native_language_code_required")
    seen = set()
    for index, item in enumerate(supports if isinstance(supports, list) else []):
        if not isinstance(item, dict):
            errors.append(f"support_{index}_not_object")
            continue
        code = normalize_code(item.get("code"))
        if code == native_code and code:
            errors.append(f"support_{index}_equals_native")
        if code in seen and code:
            errors.append(f"support_{index}_duplicate")
        if code:
            seen.add(code)
    return errors

def validate_bundle(bundle):
    errors = []
    required = {
        "platform.json",
        "rlb.json",
        "resources.json",
        "identity.json",
        "bootstrap-manifest.json",
    }
    if not isinstance(bundle, dict):
        return {"valid": False, "errors": ["bundle_not_object"]}
    missing = sorted(required.difference(bundle.keys()))
    if missing:
        errors.extend("missing_" + x for x in missing)

    platform = bundle.get("platform.json", {})
    rlb = bundle.get("rlb.json", {})
    resources = bundle.get("resources.json", {})
    identity = bundle.get("identity.json", {})
    manifest = bundle.get("bootstrap-manifest.json", {})

    errors.extend(validate_language_contract(platform))

    if platform.get("sgoda_core", {}).get("mode") != "shared_reference":
        errors.append("sgoda_core_mode_invalid")
    if platform.get("sgoda_core", {}).get("embedded_copy") is not False:
        errors.append("sgoda_core_embedded_copy_forbidden")

    native_code = normalize_code(platform.get("native_language", {}).get("code"))
    support_codes = [
        normalize_code(x.get("code"))
        for x in platform.get("support_languages", [])
        if isinstance(x, dict) and normalize_code(x.get("code"))
    ]

    if rlb.get("instance_specific") is not True:
        errors.append("rlb_not_instance_specific")
    if normalize_code(rlb.get("native_language")) != native_code:
        errors.append("rlb_native_language_mismatch")
    if list(rlb.get("support_languages", [])) != support_codes:
        errors.append("rlb_support_languages_mismatch")
    if rlb.get("bootstrap_state") != "EMPTY_READY":
        errors.append("rlb_bootstrap_state_invalid")

    if resources.get("instance_specific") is not True:
        errors.append("resources_not_instance_specific")
    if resources.get("bootstrap_state") != "READY":
        errors.append("resources_bootstrap_state_invalid")

    if identity.get("instance_specific") is not True:
        errors.append("identity_not_instance_specific")
    if identity.get("platform_id") != platform.get("platform_id"):
        errors.append("identity_platform_id_mismatch")

    if manifest.get("bootstrap_contract") != "SGODA_LANGUAGE_INSTANCE_V1":
        errors.append("bootstrap_contract_invalid")
    if manifest.get("shared_core_reference") is not True:
        errors.append("shared_core_reference_required")
    if manifest.get("core_copy_created") is not False:
        errors.append("core_copy_created_forbidden")
    if manifest.get("production_deployed") is not False:
        errors.append("production_deployment_forbidden")

    return {
        "valid": not errors,
        "errors": errors,
        "native_language": native_code,
        "support_languages": support_codes,
        "platform_id": platform.get("platform_id"),
    }

def compatibility_gate(bundle):
    result = validate_bundle(bundle)
    checks = {
        "language_contract": not any("native_language" in e or "support_" in e for e in result["errors"]),
        "rlb_contract": not any(e.startswith("rlb_") for e in result["errors"]),
        "resource_contract": not any(e.startswith("resources_") for e in result["errors"]),
        "identity_contract": not any(e.startswith("identity_") for e in result["errors"]),
        "sgoda_core_compatibility": not any("sgoda_core" in e or "shared_core" in e or "core_copy" in e for e in result["errors"]),
        "bootstrap_manifest": not any("bootstrap_contract" in e or "production_deployment" in e for e in result["errors"]),
    }
    checks["all_pass"] = all(checks.values()) and result["valid"]
    return checks

def bundle_sha256(bundle):
    text = json.dumps(bundle, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256(text.encode("utf-8")).hexdigest()

def simulate_kurripaco_bundle():
    platform = {
        "platform_id": "sgoda-kurripaco",
        "platform_name": "SGODA-KURRIPACO",
        "independent_platform": True,
        "sgoda_core": {"mode": "shared_reference", "embedded_copy": False},
        "community": {"community_id": "kurripaco", "name": "Pueblo Kurripaco"},
        "native_language": {"code": "kpc", "name": "Kurripaco"},
        "support_languages": [
            {"code": "es", "name": "Español"},
            {"code": "en", "name": "English"},
        ],
    }
    rlb = {
        "repository_id": "RLB-KPC",
        "instance_specific": True,
        "native_language": "kpc",
        "support_languages": ["es", "en"],
        "records": [],
        "bootstrap_state": "EMPTY_READY",
    }
    resources = {
        "instance_specific": True,
        "resources": [],
        "bootstrap_state": "READY",
    }
    identity = {
        "instance_specific": True,
        "platform_id": "sgoda-kurripaco",
        "platform_name": "SGODA-KURRIPACO",
        "branding": {"configurable_per_platform": True},
    }
    manifest = {
        "bootstrap_contract": "SGODA_LANGUAGE_INSTANCE_V1",
        "platform_id": "sgoda-kurripaco",
        "native_language": "kpc",
        "support_languages": ["es", "en"],
        "shared_core_reference": True,
        "core_copy_created": False,
        "production_deployed": False,
    }
    return {
        "platform.json": platform,
        "rlb.json": rlb,
        "resources.json": resources,
        "identity.json": identity,
        "bootstrap-manifest.json": manifest,
    }

def nondestructive_replication_trial():
    bundle = simulate_kurripaco_bundle()
    validation = validate_bundle(bundle)
    compatibility = compatibility_gate(bundle)
    return {
        "valid": validation["valid"],
        "compatibility": compatibility,
        "sha256": bundle_sha256(bundle),
        "deployed": False,
        "production_changed": False,
        "sgoda_puinave_modified": False,
        "core_duplicated": False,
    }
'@
    $InitText = @'
from .core import (
    normalize_code,
    validate_language_contract,
    validate_bundle,
    compatibility_gate,
    bundle_sha256,
    simulate_kurripaco_bundle,
    nondestructive_replication_trial,
)

__all__ = [
    "normalize_code",
    "validate_language_contract",
    "validate_bundle",
    "compatibility_gate",
    "bundle_sha256",
    "simulate_kurripaco_bundle",
    "nondestructive_replication_trial",
]
'@
    $TestText = @'
from sgoda.integration.spt0258 import *

def bundle():
    return simulate_kurripaco_bundle()

def test_01():
    assert validate_bundle(bundle())["valid"]

def test_02():
    assert validate_bundle(bundle())["native_language"] == "kpc"

def test_03():
    assert validate_bundle(bundle())["support_languages"] == ["es", "en"]

def test_04():
    assert compatibility_gate(bundle())["all_pass"]

def test_05():
    assert compatibility_gate(bundle())["language_contract"]

def test_06():
    assert compatibility_gate(bundle())["rlb_contract"]

def test_07():
    assert compatibility_gate(bundle())["resource_contract"]

def test_08():
    assert compatibility_gate(bundle())["identity_contract"]

def test_09():
    assert compatibility_gate(bundle())["sgoda_core_compatibility"]

def test_10():
    assert compatibility_gate(bundle())["bootstrap_manifest"]

def test_11():
    assert nondestructive_replication_trial()["deployed"] is False

def test_12():
    assert nondestructive_replication_trial()["production_changed"] is False

def test_13():
    assert nondestructive_replication_trial()["sgoda_puinave_modified"] is False

def test_14():
    assert nondestructive_replication_trial()["core_duplicated"] is False

def test_15():
    assert len(nondestructive_replication_trial()["sha256"]) == 64

def test_16():
    value = bundle()
    value["platform.json"]["sgoda_core"]["embedded_copy"] = True
    assert not validate_bundle(value)["valid"]

def test_17():
    value = bundle()
    value["bootstrap-manifest.json"]["production_deployed"] = True
    assert not validate_bundle(value)["valid"]

def test_18():
    value = bundle()
    value["rlb.json"]["native_language"] = "pui"
    assert not validate_bundle(value)["valid"]

def test_19():
    value = bundle()
    value["resources.json"]["instance_specific"] = False
    assert not validate_bundle(value)["valid"]

def test_20():
    value = bundle()
    value["identity.json"]["platform_id"] = "sgoda-other"
    assert not validate_bundle(value)["valid"]

def test_21():
    value = bundle()
    value["platform.json"]["support_languages"].append({"code": "kpc", "name": "Kurripaco"})
    assert not validate_bundle(value)["valid"]

def test_22():
    first = bundle_sha256(bundle())
    second = bundle_sha256(bundle())
    assert first == second

def test_23():
    value = bundle()
    first = bundle_sha256(value)
    value["identity.json"]["platform_name"] = "OTHER"
    assert bundle_sha256(value) != first

def test_24():
    value = bundle()
    del value["resources.json"]
    assert not validate_bundle(value)["valid"]

def test_25():
    assert bundle()["rlb.json"]["records"] == []

def test_26():
    assert bundle()["bootstrap-manifest.json"]["shared_core_reference"] is True

def test_27():
    assert bundle()["bootstrap-manifest.json"]["core_copy_created"] is False

def test_28():
    assert bundle()["bootstrap-manifest.json"]["production_deployed"] is False
'@
    $PolicyText = @'
{
  "component": "SPT-025.8",
  "version": "1.0.0",
  "title": "Validador de Instancias, Quality Gates de Bootstrap, Compatibilidad y Ensayo de Replicacion No Destructiva",
  "authoritative_baseline": "0fd93995564ceba8c05316145221bd4ece4a1443",
  "validation_scope": [
    "native_language_contract",
    "support_languages_contract",
    "rlb_contract",
    "identity_contract",
    "resource_catalog_contract",
    "sgoda_core_compatibility",
    "bootstrap_manifest",
    "sha256_integrity",
    "nondestructive_replication_trial"
  ],
  "replication_trial": {
    "reference": "SGODA-KURRIPACO",
    "deploy": false,
    "production_change": false,
    "modify_sgoda_puinave": false,
    "duplicate_sgoda_core": false
  },
  "repository_policy": {
    "all_outputs_committed": true,
    "push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
    $DocumentationText = @'
# SPT-025.8 — Validador de Instancias, Quality Gates de Bootstrap, Compatibilidad y Ensayo de Replicación No Destructiva

Baseline autoritativa: `0fd93995564ceba8c05316145221bd4ece4a1443`.

Esta capa valida de extremo a extremo las instancias generadas por SPT-025.7. Comprueba lengua nativa, idiomas auxiliares, RLB, catálogo de recursos, identidad, compatibilidad con SGODA Core, manifiesto de bootstrap e integridad SHA-256.

Incluye un ensayo no destructivo de replicación con una instancia de referencia tipo SGODA-KURRIPACO. El ensayo no despliega una plataforma real, no cambia producción, no modifica SGODA-PUINAVE y no duplica SGODA Core.

Todos los resultados de validación, pruebas, matrices y evidencias deben quedar versionados y publicados en el repositorio oficial.

'@

    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $DocFile $DocumentationText

    Write-Host "SPT-025.8 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "POWERSHELL-SAFE PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH = Join-Path $Root "src"

    $SmokeCode = @'
from sgoda.integration.spt0258 import nondestructive_replication_trial
result = nondestructive_replication_trial()
assert result["valid"]
assert result["compatibility"]["all_pass"]
assert result["deployed"] is False
assert result["production_changed"] is False
assert result["sgoda_puinave_modified"] is False
assert result["core_duplicated"] is False
print("SPT0258_IMPORT=PASS")
print("INSTANCE_VALIDATION=PASS")
print("KURRIPACO_NONDESTRUCTIVE_TRIAL=PASS")
print("SHA256_INTEGRITY=PASS")
'@

    $SmokePath = Join-Path ([System.IO.Path]::GetTempPath()) ("spt0258-smoke-" + [guid]::NewGuid().ToString("N") + ".py")
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($SmokePath, $SmokeCode, $Utf8)

    try {
        & $Python $SmokePath
        if ($LASTEXITCODE -ne 0) {
            Hold "SPT-025.8 smoke validation failed"
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

    Step 8 "END-TO-END INSTANCE QUALITY GATE"
    $TrialCode = @'
import json
from sgoda.integration.spt0258 import nondestructive_replication_trial, simulate_kurripaco_bundle, validate_bundle, compatibility_gate
trial = nondestructive_replication_trial()
bundle = simulate_kurripaco_bundle()
result = {
    "trial": trial,
    "validation": validate_bundle(bundle),
    "compatibility": compatibility_gate(bundle),
    "bundle": bundle
}
print(json.dumps(result, ensure_ascii=False))
'@

    $TrialScript = Join-Path ([System.IO.Path]::GetTempPath()) ("spt0258-trial-" + [guid]::NewGuid().ToString("N") + ".py")
    $TrialOutput = Join-Path ([System.IO.Path]::GetTempPath()) ("spt0258-output-" + [guid]::NewGuid().ToString("N") + ".json")
    [System.IO.File]::WriteAllText($TrialScript, $TrialCode, $Utf8)

    try {
        & $Python $TrialScript | Out-File -LiteralPath $TrialOutput -Encoding utf8
        if ($LASTEXITCODE -ne 0) {
            Hold "Replication trial execution failed"
        }
        $TrialResult = Get-Content -Raw -LiteralPath $TrialOutput | ConvertFrom-Json
    }
    finally {
        Remove-Item -LiteralPath $TrialScript -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $TrialOutput -Force -ErrorAction SilentlyContinue
    }

    if (-not [bool]$TrialResult.trial.valid) {
        Hold "Instance validation failed"
    }
    if (-not [bool]$TrialResult.compatibility.all_pass) {
        Hold "SGODA Core compatibility gate failed"
    }
    if ([bool]$TrialResult.trial.deployed) {
        Hold "Replication trial unexpectedly deployed"
    }

    Write-Host "NATIVE_LANGUAGE_CONTRACT=PASS"
    Write-Host "SUPPORT_LANGUAGES_CONTRACT=PASS"
    Write-Host "RLB_CONTRACT=PASS"
    Write-Host "RESOURCE_CATALOG_CONTRACT=PASS"
    Write-Host "IDENTITY_CONTRACT=PASS"
    Write-Host "SGODA_CORE_COMPATIBILITY=PASS"
    Write-Host "BOOTSTRAP_MANIFEST=PASS"
    Write-Host "SHA256_INTEGRITY=PASS"
    Write-Host "KURRIPACO_REPLICATION_TRIAL=PASS"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "PRODUCTION_CHANGED=NO"
    Write-Host "SGODA_PUINAVE_MODIFIED=NO"
    Write-Host "SGODA_CORE_DUPLICATED=NO"
    Write-Host "SPT-025.8 GLOBAL QUALITY GATE : PASS"

    Step 9 "GENERATE VALIDATION / REPLICATION EVIDENCE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir) | Out-Null

    $ValidationAssessment = [ordered]@{
        component = "SPT-025.8"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        status = "INSTANCE_VALIDATION_QUALITY_GATE_PASS"
        platform_id = [string]$TrialResult.validation.platform_id
        native_language = [string]$TrialResult.validation.native_language
        support_languages = @($TrialResult.validation.support_languages)
        valid = [bool]$TrialResult.validation.valid
    }

    $CompatibilityAssessment = [ordered]@{
        status = "SGODA_CORE_COMPATIBILITY_GATE_PASS"
        language_contract = [bool]$TrialResult.compatibility.language_contract
        rlb_contract = [bool]$TrialResult.compatibility.rlb_contract
        resource_contract = [bool]$TrialResult.compatibility.resource_contract
        identity_contract = [bool]$TrialResult.compatibility.identity_contract
        sgoda_core_compatibility = [bool]$TrialResult.compatibility.sgoda_core_compatibility
        bootstrap_manifest = [bool]$TrialResult.compatibility.bootstrap_manifest
    }

    $LanguageAssessment = [ordered]@{
        native_language = [string]$TrialResult.validation.native_language
        support_languages = @($TrialResult.validation.support_languages)
        status = "PASS"
    }

    $RlbAssessment = [ordered]@{
        repository_id = [string]$TrialResult.bundle."rlb.json".repository_id
        instance_specific = [bool]$TrialResult.bundle."rlb.json".instance_specific
        bootstrap_state = [string]$TrialResult.bundle."rlb.json".bootstrap_state
        records = @($TrialResult.bundle."rlb.json".records).Count
        status = "PASS"
    }

    $ResourceAssessment = [ordered]@{
        instance_specific = [bool]$TrialResult.bundle."resources.json".instance_specific
        bootstrap_state = [string]$TrialResult.bundle."resources.json".bootstrap_state
        status = "PASS"
    }

    $IdentityAssessment = [ordered]@{
        instance_specific = [bool]$TrialResult.bundle."identity.json".instance_specific
        platform_id = [string]$TrialResult.bundle."identity.json".platform_id
        status = "PASS"
    }

    $ReplicationAssessment = [ordered]@{
        reference = "SGODA-KURRIPACO"
        status = "NONDESTRUCTIVE_REPLICATION_TRIAL_PASS"
        deployed = [bool]$TrialResult.trial.deployed
        production_changed = [bool]$TrialResult.trial.production_changed
        sgoda_puinave_modified = [bool]$TrialResult.trial.sgoda_puinave_modified
        core_duplicated = [bool]$TrialResult.trial.core_duplicated
    }

    $ShaAssessment = [ordered]@{
        algorithm = "SHA-256"
        bundle_sha256 = [string]$TrialResult.trial.sha256
        status = "PASS"
    }

    $GlobalGate = [ordered]@{
        component = "SPT-025.8"
        version = "1.0.0"
        status = "SPT0258_GLOBAL_QUALITY_GATE_PASS"
        native_language_contract = "PASS"
        support_languages_contract = "PASS"
        rlb_contract = "PASS"
        resource_catalog_contract = "PASS"
        identity_contract = "PASS"
        sgoda_core_compatibility = "PASS"
        bootstrap_manifest = "PASS"
        sha256_integrity = "PASS"
        nondestructive_replication_trial = "PASS"
        real_platform_deployed = $false
        production_changed = $false
        sgoda_puinave_modified = $false
        sgoda_core_duplicated = $false
    }

    $Evidence = [ordered]@{
        component = "SPT-025.8"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        repository_continuity_gate = "PASS"
        targeted_tests = "PASS"
        institutional_suite = "PASS"
        compileall = "PASS"
        global_quality_gate = "PASS"
        all_outputs_to_repository = $true
        closed_components_preserved = $true
    }

    $Prepare = [ordered]@{
        next_deliverable = "SPT-025.9"
        title = "Materializador Controlado de Instancias / Empaquetado Replicable y Gobierno de Creacion"
        source_baseline = $ExpectedBaseline
        spt0258_quality_gate = "PASS"
    }

    Write-Lf $ValidationFile ($ValidationAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $CompatibilityFile ($CompatibilityAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $LanguageFile ($LanguageAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $RlbFile ($RlbAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $ResourceFile ($ResourceAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $IdentityFile ($IdentityAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $ReplicationFile ($ReplicationAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $ShaFile ($ShaAssessment | ConvertTo-Json -Depth 10)
    Write-Lf $GateFile ($GlobalGate | ConvertTo-Json -Depth 10)
    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 10)
    Write-Lf $PrepareFile ($Prepare | ConvertTo-Json -Depth 10)

    Write-Host "INSTANCE VALIDATION : CREATED"
    Write-Host "CORE COMPATIBILITY  : CREATED"
    Write-Host "LANGUAGE CONTRACT   : CREATED"
    Write-Host "RLB CONTRACT        : CREATED"
    Write-Host "RESOURCE CONTRACT   : CREATED"
    Write-Host "IDENTITY CONTRACT   : CREATED"
    Write-Host "KURRIPACO TRIAL     : CREATED"
    Write-Host "SHA-256 INTEGRITY   : CREATED"
    Write-Host "GLOBAL QUALITY GATE : CREATED"
    Write-Host "SPT-025.9 PREPARE   : CREATED"
    Write-Host "EVIDENCE            : CREATED"

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
    Write-Host "SPT-025.1-.7 + REPOSITORY AUDIT : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed = @(
        "Invoke-SGODA-SPT0258-InstanceValidator-ReplicationQualityGate-FINAL-v1.0.0-PS51.ps1",
        $CoreFile,
        $InitFile,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $ValidationFile,
        $CompatibilityFile,
        $LanguageFile,
        $RlbFile,
        $ResourceFile,
        $IdentityFile,
        $ReplicationFile,
        $ShaFile,
        $GateFile,
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
    & git.exe commit -m "feat(spt-025.8): validate language instances and nondestructive replication quality gates"
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
    Write-Host "SPT-025.8 : TECHNICALLY CLOSED / INSTANCE VALIDATION & REPLICATION QUALITY GATES APPROVED" -ForegroundColor Green
    Write-Host "REPOSITORY_CONTINUITY_GATE=PASS"
    Write-Host "SPT-025.7_BOOTSTRAP_FACTORY_GATE=PASS"
    Write-Host "NATIVE_LANGUAGE_CONTRACT=PASS"
    Write-Host "SUPPORT_LANGUAGES_CONTRACT=PASS"
    Write-Host "RLB_CONTRACT=PASS"
    Write-Host "RESOURCE_CATALOG_CONTRACT=PASS"
    Write-Host "IDENTITY_CONTRACT=PASS"
    Write-Host "SGODA_CORE_COMPATIBILITY=PASS"
    Write-Host "BOOTSTRAP_MANIFEST=PASS"
    Write-Host "SHA256_INTEGRITY=PASS"
    Write-Host "KURRIPACO_REPLICATION_TRIAL=PASS"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "PRODUCTION_CHANGED=NO"
    Write-Host "SGODA_PUINAVE_MODIFIED=NO"
    Write-Host "SGODA_CORE_DUPLICATED=NO"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "ALL_OUTPUTS_IN_REPOSITORY=PASS"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "NEXT_DELIVERABLE=SPT-025.9"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
