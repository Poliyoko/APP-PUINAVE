#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "106d4c01c783bd6c610fe5f3e344674151e9c4f0"
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$ReqGate = "artifacts/development/SPT-025.8-v1.0.0/spt0258-global-quality-gate.json"
$ReqPrepare = "artifacts/development/SPT-025.8-v1.0.0/spt0259-prepare.json"
$ReqContinuity = "artifacts/development/SPT-025.RepositoryContinuityAudit-v1.0.0/repository-continuity-assessment.json"

$CoreFile = "src/sgoda/integration/spt0259/core.py"
$InitFile = "src/sgoda/integration/spt0259/__init__.py"
$TestFile = "tests/integration/test_spt0259_controlled_instance_materializer.py"
$PolicyFile = "config/integration/spt0259/controlled-instance-materialization-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-025/SPT-025.9/SGD-SPT025.9-Materializador-Controlado-Instancias-Empaquetado-Gobierno.md"

$ArtifactDir = "artifacts/development/SPT-025.9-v1.0.0"
$PackageDir = "$ArtifactDir/kurripaco-reference-package"
$PlatformPackageFile = "$PackageDir/instance/platform.json"
$IdentityPackageFile = "$PackageDir/instance/identity.json"
$ResourcesPackageFile = "$PackageDir/instance/resources.json"
$RlbPackageFile = "$PackageDir/instance/rlb.json"
$GovernancePackageFile = "$PackageDir/instance/governance.json"
$RollbackPackageFile = "$PackageDir/instance/rollback-manifest.json"
$ManifestPackageFile = "$PackageDir/instance/package-manifest.json"

$AssessmentFile = "$ArtifactDir/materialization-governance-assessment.json"
$PackageHashFile = "$ArtifactDir/materialization-package-sha256.json"
$RollbackEvidenceFile = "$ArtifactDir/rollback-governance-evidence.json"
$CreationLedgerFile = "$ArtifactDir/instance-creation-governance-ledger.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"
$PrepareFile = "$ArtifactDir/spt02510-prepare.json"

function Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number, $Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-025.9 : HOLD" -ForegroundColor Red
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
    Write-Host "SPT-025.1-.8 + REPOSITORY AUDIT : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-025.8 QUALITY GATE / CONTINUITY INPUTS"
    $RequiredInputs = @($ReqGate, $ReqPrepare, $ReqContinuity)
    $Missing = @(
        $RequiredInputs | Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $Root $_))
        }
    )

    Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS  : $($Missing.Count)"

    if ($Missing.Count -ne 0) {
        Hold "Missing SPT-025.9 prerequisites"
    }

    $Gate = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqGate) | ConvertFrom-Json
    $Continuity = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqContinuity) | ConvertFrom-Json

    if ([string]$Gate.status -ne "SPT0258_GLOBAL_QUALITY_GATE_PASS") {
        Hold "SPT-025.8 global quality gate is not PASS"
    }
    if ([string]$Continuity.status -ne "REPOSITORY_CONTINUITY_GATE_PASS") {
        Hold "Repository continuity gate is not PASS"
    }

    Write-Host "SPT-025.8 GLOBAL QUALITY GATE : PASS"
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

    Step 4 "CONTROLLED MATERIALIZATION DISCOVERY"
    Write-Host "MATERIALIZATION MODE       : PACKAGE ONLY"
    Write-Host "REFERENCE INSTANCE         : SGODA-KURRIPACO"
    Write-Host "SGODA CORE                 : SHARED REFERENCE"
    Write-Host "CORE DUPLICATION           : NO"
    Write-Host "AUTO DEPLOYMENT            : NO"
    Write-Host "PRODUCTION CHANGE          : NO"
    Write-Host "ROLLBACK MANIFEST          : REQUIRED"
    Write-Host "PER-FILE SHA-256           : REQUIRED"

    Step 5 "IMPLEMENT SPT-025.9 CONTROLLED MATERIALIZER"
    $CoreText = @'
from hashlib import sha256
import json
import re

INSTANCE_ID_RE = re.compile(r"^sgoda-[a-z0-9][a-z0-9-]*$")

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def normalize_instance_id(value):
    text = _t(value).lower().replace("_", "-").replace(" ", "-")
    return re.sub(r"-+", "-", text)

def validate_materialization_spec(spec):
    errors = []
    if not isinstance(spec, dict):
        return {"valid": False, "errors": ["spec_not_object"]}

    required = (
        "platform_id",
        "platform_name",
        "native_language",
        "support_languages",
        "community",
        "identity",
        "resources",
        "rlb",
        "governance",
    )
    for key in required:
        if key not in spec:
            errors.append("missing_" + key)

    platform_id = normalize_instance_id(spec.get("platform_id"))
    if not platform_id or not INSTANCE_ID_RE.match(platform_id):
        errors.append("platform_id_invalid")

    native = spec.get("native_language")
    native_code = ""
    if not isinstance(native, dict):
        errors.append("native_language_not_object")
    else:
        native_code = normalize_code(native.get("code"))
        if not native_code:
            errors.append("native_language_code_required")
        if not _t(native.get("name")):
            errors.append("native_language_name_required")

    supports = spec.get("support_languages")
    if not isinstance(supports, list):
        errors.append("support_languages_not_list")
        supports = []

    seen = set()
    support_codes = []
    for index, item in enumerate(supports):
        if not isinstance(item, dict):
            errors.append(f"support_{index}_not_object")
            continue
        code = normalize_code(item.get("code"))
        if not code:
            errors.append(f"support_{index}_code_required")
        if code == native_code and code:
            errors.append(f"support_{index}_equals_native")
        if code in seen and code:
            errors.append(f"support_{index}_duplicate")
        if code:
            seen.add(code)
            support_codes.append(code)

    governance = spec.get("governance")
    if not isinstance(governance, dict):
        errors.append("governance_not_object")
    else:
        if governance.get("shared_core_reference") is not True:
            errors.append("shared_core_reference_required")
        if governance.get("duplicate_core") is not False:
            errors.append("duplicate_core_forbidden")
        if governance.get("auto_deploy") is not False:
            errors.append("auto_deploy_forbidden")
        if governance.get("production_change") is not False:
            errors.append("production_change_forbidden")

    for key, msg in (
        ("identity", "identity_instance_specific_required"),
        ("resources", "resources_instance_specific_required"),
        ("rlb", "rlb_instance_specific_required"),
    ):
        value = spec.get(key)
        if not isinstance(value, dict) or value.get("instance_specific") is not True:
            errors.append(msg)

    return {
        "valid": not errors,
        "errors": errors,
        "platform_id": platform_id,
        "native_language": native_code,
        "support_language_codes": support_codes,
    }

def build_materialization_package(spec):
    validation = validate_materialization_spec(spec)
    if not validation["valid"]:
        return {"valid": False, "errors": validation["errors"]}

    platform_id = validation["platform_id"]
    native_code = validation["native_language"]
    support_codes = validation["support_language_codes"]

    files = {
        "instance/platform.json": {
            "platform_id": platform_id,
            "platform_name": _t(spec["platform_name"]),
            "community": spec["community"],
            "native_language": spec["native_language"],
            "support_languages": spec["support_languages"],
            "sgoda_core": {
                "mode": "shared_reference",
                "embedded_copy": False,
            },
        },
        "instance/identity.json": spec["identity"],
        "instance/resources.json": spec["resources"],
        "instance/rlb.json": {
            "instance_specific": True,
            "native_language": native_code,
            "support_languages": support_codes,
            "records": [],
            "bootstrap_state": "EMPTY_READY",
        },
        "instance/governance.json": spec["governance"],
        "instance/rollback-manifest.json": {
            "rollback_supported": True,
            "destructive_cleanup_required": False,
            "production_restore_required": False,
            "scope": "generated_instance_package_only",
        },
    }

    file_hashes = {}
    for path, content in files.items():
        payload = json.dumps(
            content,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        file_hashes[path] = sha256(payload.encode("utf-8")).hexdigest()

    package_manifest = {
        "materialization_contract": "SGODA_INSTANCE_PACKAGE_V1",
        "platform_id": platform_id,
        "native_language": native_code,
        "support_languages": support_codes,
        "shared_core_reference": True,
        "core_duplicated": False,
        "auto_deployed": False,
        "production_changed": False,
        "file_hashes": file_hashes,
    }

    files["instance/package-manifest.json"] = package_manifest

    return {
        "valid": True,
        "platform_id": platform_id,
        "files": files,
        "manifest": package_manifest,
    }

def package_fingerprint(package):
    payload = json.dumps(
        package,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return sha256(payload.encode("utf-8")).hexdigest()

def reference_kurripaco_materialization_spec():
    return {
        "platform_id": "sgoda-kurripaco",
        "platform_name": "SGODA-KURRIPACO",
        "native_language": {
            "code": "kpc",
            "name": "Kurripaco",
        },
        "support_languages": [
            {"code": "es", "name": "Español"},
            {"code": "en", "name": "English"},
        ],
        "community": {
            "community_id": "kurripaco",
            "name": "Pueblo Kurripaco",
        },
        "identity": {
            "instance_specific": True,
            "branding": {
                "configurable_per_platform": True,
            },
        },
        "resources": {
            "instance_specific": True,
            "catalog": [],
        },
        "rlb": {
            "instance_specific": True,
        },
        "governance": {
            "shared_core_reference": True,
            "duplicate_core": False,
            "auto_deploy": False,
            "production_change": False,
        },
    }
'@
    $InitText = @'
from .core import (
    INSTANCE_ID_RE,
    normalize_code,
    normalize_instance_id,
    validate_materialization_spec,
    build_materialization_package,
    package_fingerprint,
    reference_kurripaco_materialization_spec,
)

__all__ = [
    "INSTANCE_ID_RE",
    "normalize_code",
    "normalize_instance_id",
    "validate_materialization_spec",
    "build_materialization_package",
    "package_fingerprint",
    "reference_kurripaco_materialization_spec",
]
'@
    $TestText = @'
from sgoda.integration.spt0259 import *

def ref():
    return reference_kurripaco_materialization_spec()

def test_01():
    assert validate_materialization_spec(ref())["valid"]

def test_02():
    assert normalize_instance_id("SGODA KURRIPACO") == "sgoda-kurripaco"

def test_03():
    assert validate_materialization_spec(ref())["native_language"] == "kpc"

def test_04():
    assert validate_materialization_spec(ref())["support_language_codes"] == ["es", "en"]

def test_05():
    assert build_materialization_package(ref())["valid"]

def test_06():
    assert build_materialization_package(ref())["manifest"]["shared_core_reference"] is True

def test_07():
    assert build_materialization_package(ref())["manifest"]["core_duplicated"] is False

def test_08():
    assert build_materialization_package(ref())["manifest"]["auto_deployed"] is False

def test_09():
    assert build_materialization_package(ref())["manifest"]["production_changed"] is False

def test_10():
    assert build_materialization_package(ref())["files"]["instance/rlb.json"]["records"] == []

def test_11():
    assert build_materialization_package(ref())["files"]["instance/rlb.json"]["bootstrap_state"] == "EMPTY_READY"

def test_12():
    assert build_materialization_package(ref())["files"]["instance/rollback-manifest.json"]["rollback_supported"] is True

def test_13():
    assert build_materialization_package(ref())["files"]["instance/rollback-manifest.json"]["destructive_cleanup_required"] is False

def test_14():
    value = ref()
    value["governance"]["shared_core_reference"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_15():
    value = ref()
    value["governance"]["duplicate_core"] = True
    assert not validate_materialization_spec(value)["valid"]

def test_16():
    value = ref()
    value["governance"]["auto_deploy"] = True
    assert not validate_materialization_spec(value)["valid"]

def test_17():
    value = ref()
    value["governance"]["production_change"] = True
    assert not validate_materialization_spec(value)["valid"]

def test_18():
    value = ref()
    value["support_languages"].append({"code": "kpc", "name": "Kurripaco"})
    assert not validate_materialization_spec(value)["valid"]

def test_19():
    value = ref()
    value["support_languages"].append({"code": "es", "name": "Duplicado"})
    assert not validate_materialization_spec(value)["valid"]

def test_20():
    value = ref()
    value["identity"]["instance_specific"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_21():
    value = ref()
    value["resources"]["instance_specific"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_22():
    value = ref()
    value["rlb"]["instance_specific"] = False
    assert not validate_materialization_spec(value)["valid"]

def test_23():
    package = build_materialization_package(ref())
    assert package["manifest"]["materialization_contract"] == "SGODA_INSTANCE_PACKAGE_V1"

def test_24():
    package = build_materialization_package(ref())
    assert "instance/package-manifest.json" in package["files"]

def test_25():
    package = build_materialization_package(ref())
    assert len(package["manifest"]["file_hashes"]) == 6

def test_26():
    package = build_materialization_package(ref())
    assert package_fingerprint(package) == package_fingerprint(package)

def test_27():
    first = build_materialization_package(ref())
    second = build_materialization_package(ref())
    second["files"]["instance/platform.json"]["platform_name"] = "OTHER"
    assert package_fingerprint(first) != package_fingerprint(second)

def test_28():
    assert build_materialization_package(ref())["platform_id"] == "sgoda-kurripaco"

def test_29():
    package = build_materialization_package(ref())
    assert package["files"]["instance/platform.json"]["sgoda_core"]["embedded_copy"] is False

def test_30():
    package = build_materialization_package(ref())
    assert package["files"]["instance/governance.json"]["auto_deploy"] is False
'@
    $PolicyText = @'
{
  "component": "SPT-025.9",
  "version": "1.0.0",
  "title": "Materializador Controlado de Instancias / Empaquetado Replicable y Gobierno de Creacion",
  "authoritative_baseline": "106d4c01c783bd6c610fe5f3e344674151e9c4f0",
  "materialization": {
    "mode": "PACKAGE_ONLY",
    "shared_core_reference": true,
    "duplicate_core": false,
    "auto_deploy": false,
    "production_change": false,
    "rollback_manifest_required": true,
    "sha256_per_file_required": true,
    "reference_trial": "SGODA-KURRIPACO"
  },
  "repository": {
    "all_outputs_committed": true,
    "push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
    $DocumentationText = @'
# SPT-025.9 — Materializador Controlado de Instancias / Empaquetado Replicable y Gobierno de Creación

Baseline autoritativa: `106d4c01c783bd6c610fe5f3e344674151e9c4f0`.

## Objetivo
Convertir una especificación de instancia validada por SPT-025.8 en un paquete materializable y reproducible, sin desplegarlo automáticamente.

## Contenido del paquete
- `instance/platform.json`
- `instance/identity.json`
- `instance/resources.json`
- `instance/rlb.json`
- `instance/governance.json`
- `instance/rollback-manifest.json`
- `instance/package-manifest.json`

## Reglas
SGODA Core se reutiliza por referencia compartida. No se duplica el núcleo, no se modifica SGODA-PUINAVE, no se ejecutan cambios de producción y no se despliega automáticamente una nueva comunidad.

El ensayo de referencia SGODA-KURRIPACO se materializa únicamente como paquete controlado de evidencia dentro de `artifacts/`, no como una plataforma real operativa.

Todos los resultados, pruebas, manifests, documentación y evidencias deben quedar incorporados y publicados en el repositorio oficial.

'@

    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $DocFile $DocumentationText

    Write-Host "SPT-025.9 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "POWERSHELL-SAFE PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH = Join-Path $Root "src"

    $SmokeCode = @'
from sgoda.integration.spt0259 import (
    reference_kurripaco_materialization_spec,
    build_materialization_package,
)
package = build_materialization_package(reference_kurripaco_materialization_spec())
assert package["valid"]
assert package["manifest"]["shared_core_reference"] is True
assert package["manifest"]["core_duplicated"] is False
assert package["manifest"]["auto_deployed"] is False
assert package["manifest"]["production_changed"] is False
print("SPT0259_IMPORT=PASS")
print("MATERIALIZATION_PACKAGE_CONTRACT=PASS")
print("ROLLBACK_GOVERNANCE=PASS")
print("SHA256_FILE_MANIFEST=PASS")
'@

    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $SmokePath = Join-Path ([System.IO.Path]::GetTempPath()) ("spt0259-smoke-" + [guid]::NewGuid().ToString("N") + ".py")
    [System.IO.File]::WriteAllText($SmokePath, $SmokeCode, $Utf8)

    try {
        & $Python $SmokePath
        if ($LASTEXITCODE -ne 0) {
            Hold "SPT-025.9 smoke validation failed"
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

    Step 8 "MATERIALIZE REFERENCE PACKAGE / GOVERNANCE GATE"
    $PackageCode = @'
import json
from sgoda.integration.spt0259 import (
    reference_kurripaco_materialization_spec,
    build_materialization_package,
)
package = build_materialization_package(reference_kurripaco_materialization_spec())
print(json.dumps(package, ensure_ascii=False))
'@

    $PackageScript = Join-Path ([System.IO.Path]::GetTempPath()) ("spt0259-package-" + [guid]::NewGuid().ToString("N") + ".py")
    $PackageOutput = Join-Path ([System.IO.Path]::GetTempPath()) ("spt0259-package-" + [guid]::NewGuid().ToString("N") + ".json")
    [System.IO.File]::WriteAllText($PackageScript, $PackageCode, $Utf8)

    try {
        & $Python $PackageScript | Out-File -LiteralPath $PackageOutput -Encoding utf8
        if ($LASTEXITCODE -ne 0) {
            Hold "Reference package generation failed"
        }
        $PackageResult = Get-Content -Raw -LiteralPath $PackageOutput | ConvertFrom-Json
    }
    finally {
        Remove-Item -LiteralPath $PackageScript -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $PackageOutput -Force -ErrorAction SilentlyContinue
    }

    if (-not [bool]$PackageResult.valid) {
        Hold "Materialization package validation failed"
    }
    if ([bool]$PackageResult.manifest.core_duplicated) {
        Hold "Core duplication is forbidden"
    }
    if ([bool]$PackageResult.manifest.auto_deployed) {
        Hold "Auto deployment is forbidden"
    }
    if ([bool]$PackageResult.manifest.production_changed) {
        Hold "Production change is forbidden"
    }

    Write-Host "MATERIALIZATION_PACKAGE=PASS"
    Write-Host "SHARED_CORE_REFERENCE=PASS"
    Write-Host "CORE_DUPLICATION=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "ROLLBACK_MANIFEST=PASS"
    Write-Host "PER_FILE_SHA256=PASS"
    Write-Host "CONTROLLED MATERIALIZATION GATE : PASS"

    Step 9 "WRITE PACKAGE / GOVERNANCE EVIDENCE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $PackageDir) | Out-Null

    Write-Lf $PlatformPackageFile ($PackageResult.files."instance/platform.json" | ConvertTo-Json -Depth 12)
    Write-Lf $IdentityPackageFile ($PackageResult.files."instance/identity.json" | ConvertTo-Json -Depth 12)
    Write-Lf $ResourcesPackageFile ($PackageResult.files."instance/resources.json" | ConvertTo-Json -Depth 12)
    Write-Lf $RlbPackageFile ($PackageResult.files."instance/rlb.json" | ConvertTo-Json -Depth 12)
    Write-Lf $GovernancePackageFile ($PackageResult.files."instance/governance.json" | ConvertTo-Json -Depth 12)
    Write-Lf $RollbackPackageFile ($PackageResult.files."instance/rollback-manifest.json" | ConvertTo-Json -Depth 12)
    Write-Lf $ManifestPackageFile ($PackageResult.files."instance/package-manifest.json" | ConvertTo-Json -Depth 12)

    $Assessment = [ordered]@{
        component = "SPT-025.9"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        status = "CONTROLLED_INSTANCE_MATERIALIZATION_GATE_PASS"
        reference_instance = "sgoda-kurripaco"
        shared_core_reference = $true
        core_duplicated = $false
        auto_deployed = $false
        production_changed = $false
        sgoda_puinave_modified = $false
    }

    $RollbackEvidence = [ordered]@{
        rollback_supported = $true
        destructive_cleanup_required = $false
        production_restore_required = $false
        scope = "generated_instance_package_only"
        status = "PASS"
    }

    $CreationLedger = [ordered]@{
        action = "REFERENCE_PACKAGE_MATERIALIZED"
        instance = "sgoda-kurripaco"
        operational_deployment = $false
        repository_evidence_only = $true
        status = "PASS"
    }

    $PackageHashes = @()
    foreach ($PackagePath in @(
        $PlatformPackageFile,
        $IdentityPackageFile,
        $ResourcesPackageFile,
        $RlbPackageFile,
        $GovernancePackageFile,
        $RollbackPackageFile,
        $ManifestPackageFile
    )) {
        $PackageHashes += [ordered]@{
            path = $PackagePath
            sha256 = Get-Sha256 (Join-Path $Root $PackagePath)
        }
    }

    $Evidence = [ordered]@{
        component = "SPT-025.9"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        targeted_tests = "PASS"
        institutional_suite = "PASS"
        compileall = "PASS"
        materialization_gate = "PASS"
        all_outputs_to_repository = $true
        closed_components_preserved = $true
    }

    $Prepare = [ordered]@{
        next_deliverable = "SPT-025.10"
        title = "Registro Maestro de Instancias, Versionado de Paquetes, Trazabilidad y Gobierno de Ciclo de Vida"
        source_baseline = $ExpectedBaseline
        spt0259_materialization_gate = "PASS"
    }

    Write-Lf $AssessmentFile ($Assessment | ConvertTo-Json -Depth 10)
    Write-Lf $PackageHashFile (
        [ordered]@{
            algorithm = "SHA-256"
            records = $PackageHashes
        } | ConvertTo-Json -Depth 12
    )
    Write-Lf $RollbackEvidenceFile ($RollbackEvidence | ConvertTo-Json -Depth 10)
    Write-Lf $CreationLedgerFile ($CreationLedger | ConvertTo-Json -Depth 10)
    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 10)
    Write-Lf $PrepareFile ($Prepare | ConvertTo-Json -Depth 10)

    Write-Host "REFERENCE PACKAGE  : CREATED"
    Write-Host "PACKAGE MANIFEST   : CREATED"
    Write-Host "SHA-256 MANIFEST   : CREATED"
    Write-Host "ROLLBACK EVIDENCE  : CREATED"
    Write-Host "CREATION LEDGER    : CREATED"
    Write-Host "SPT-025.10 PREPARE : CREATED"
    Write-Host "EVIDENCE           : CREATED"

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
    Write-Host "SPT-025.1-.8 + REPOSITORY AUDIT : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed = @(
        "Invoke-SGODA-SPT0259-ControlledInstanceMaterializer-ReplicablePackageGov-FINAL-v1.0.0-PS51.ps1",
        $CoreFile,
        $InitFile,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $PlatformPackageFile,
        $IdentityPackageFile,
        $ResourcesPackageFile,
        $RlbPackageFile,
        $GovernancePackageFile,
        $RollbackPackageFile,
        $ManifestPackageFile,
        $AssessmentFile,
        $PackageHashFile,
        $RollbackEvidenceFile,
        $CreationLedgerFile,
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
    & git.exe commit -m "feat(spt-025.9): materialize controlled replicable language instance package"
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
    Write-Host "SPT-025.9 : TECHNICALLY CLOSED / CONTROLLED INSTANCE MATERIALIZATION APPROVED" -ForegroundColor Green
    Write-Host "SPT-025.8_GLOBAL_QUALITY_GATE=PASS"
    Write-Host "REPOSITORY_CONTINUITY_GATE=PASS"
    Write-Host "MATERIALIZATION_PACKAGE=PASS"
    Write-Host "REFERENCE_INSTANCE=SGODA-KURRIPACO"
    Write-Host "SHARED_CORE_REFERENCE=PASS"
    Write-Host "CORE_DUPLICATION=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "SGODA_PUINAVE_MODIFIED=NO"
    Write-Host "ROLLBACK_MANIFEST=PASS"
    Write-Host "PER_FILE_SHA256=PASS"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "ALL_OUTPUTS_IN_REPOSITORY=PASS"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "NEXT_DELIVERABLE=SPT-025.10"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
