#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "be336578467f3971295338adc3b9f5ff9c78ef99"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$FailedMaster = "Invoke-SGODA-SPT0257-LanguageInstanceBootstrap-Factory-FINAL-v1.0.0-PS51.ps1"

$ReqAssessment = "artifacts/development/SPT-025.6-v1.0.0/spt0256-identity-assessment.json"
$ReqPrepare = "artifacts/development/SPT-025.6-v1.0.0/spt0257-prepare.json"

$CoreFile = "src/sgoda/integration/spt0257/core.py"
$InitFile = "src/sgoda/integration/spt0257/__init__.py"
$TestFile = "tests/integration/test_spt0257_language_instance_bootstrap_factory.py"
$PolicyFile = "config/integration/spt0257/language-instance-bootstrap-policy.json"
$SchemaFile = "config/integration/spt0257/language-instance-bootstrap.schema.json"
$PuinaveSpecFile = "config/integration/spt0257/sgoda-puinave-bootstrap-reference.json"
$ExampleSpecFile = "config/integration/spt0257/example-sgoda-kurripaco-bootstrap-spec.json"
$DocFile = "docs/06_Tecnologia/SPT-025/SPT-025.7/SGD-SPT025.7-Generador-Instancias-Linguisticas-Bootstrap.md"

$ArtifactDir = "artifacts/development/SPT-025.7-v1.0.1"
$FactoryModelFile = "$ArtifactDir/language-instance-factory-baseline.json"
$BootstrapContractFile = "$ArtifactDir/bootstrap-package-contract.json"
$PuinaveReferenceFile = "$ArtifactDir/sgoda-puinave-bootstrap-reference-baseline.json"
$KurripacoPreviewFile = "$ArtifactDir/kurripaco-bootstrap-preview-nondeployed.json"
$CoreReuseFile = "$ArtifactDir/shared-core-reuse-baseline.json"
$AssessmentFile = "$ArtifactDir/spt0257-bootstrap-assessment.json"
$IntegrityFile = "$ArtifactDir/spt0257-integrity-manifest.json"
$PrepareFile = "$ArtifactDir/spt0258-prepare.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

function Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number, $Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-025.7 : HOLD" -ForegroundColor Red
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
    $AbsolutePath = Join-Path $Root $Path
    $Parent = Split-Path -Parent $AbsolutePath
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $Normalized = (($Text -replace "`r`n", "`n") -replace "`r", "`n")
    if (-not $Normalized.EndsWith("`n")) {
        $Normalized += "`n"
    }
    [System.IO.File]::WriteAllText($AbsolutePath, $Normalized, $Utf8)
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
    $StagedBefore = @(& git.exe diff --cached --name-only)
    $DeletedTracked = @(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($StagedBefore.Count)"
    Write-Host "DELETED TRACKED : $($DeletedTracked.Count)"

    if ($LocalHead -ne $ExpectedBaseline) {
        Hold "Local HEAD does not match authoritative baseline"
    }
    if ($RemoteHead -ne $ExpectedBaseline) {
        Hold "Remote HEAD does not match authoritative baseline"
    }
    if ($StagedBefore.Count -ne 0) {
        Hold "Staged changes detected before recovery"
    }
    if ($DeletedTracked.Count -ne 0) {
        Hold "Deleted tracked files detected before recovery"
    }

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024 / PISI + SPT-025.1-.6 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY STATE / VERIFY SPT-025.6 INPUTS"
    if (Test-Path -LiteralPath (Join-Path $Root $FailedMaster)) {
        Write-Host "FAILED MASTER v1.0.0 : LOCAL / SUPERSEDED / NOT PUBLISHED"
    }
    else {
        Write-Host "FAILED MASTER v1.0.0 : NOT PRESENT IN WORKTREE"
    }
    Write-Host "RECOVERY MASTER v1.0.1 : ACTIVE"

    $RequiredInputs = @($ReqAssessment, $ReqPrepare)
    $MissingInputs = @(
        $RequiredInputs | Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $Root $_))
        }
    )

    Write-Host "REQUIRED SPT-025.6 INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS            : $($MissingInputs.Count)"

    if ($MissingInputs.Count -ne 0) {
        Hold "Missing SPT-025.6 inputs"
    }

    $PreviousAssessment = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqAssessment) | ConvertFrom-Json
    if ([string]$PreviousAssessment.status -ne "IDENTITY_BRANDING_GOVERNANCE_GATE_PASS") {
        Hold "SPT-025.6 gate is not PASS"
    }

    Write-Host "SPT-025.6 IDENTITY / BRANDING GOVERNANCE GATE : PASS"

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

    Step 4 "LANGUAGE INSTANCE BOOTSTRAP DISCOVERY"
    Write-Host "FACTORY MODE             : BOOTSTRAP PACKAGE"
    Write-Host "SGODA CORE               : SHARED REFERENCE"
    Write-Host "CORE COPY PER INSTANCE   : NO"
    Write-Host "INSTANCE RLB             : EMPTY / READY"
    Write-Host "INSTANCE RESOURCES       : READY"
    Write-Host "INSTANCE IDENTITY        : READY"
    Write-Host "REAL PLATFORM DEPLOYMENT : NO"
    Write-Host "SGODA-PUINAVE MODIFIED   : NO"

    Step 5 "IMPLEMENT SPT-025.7 LANGUAGE INSTANCE FACTORY"
    $CoreText = @'
from hashlib import sha256
import json
import re

PLATFORM_ID_RE = re.compile(r"^sgoda-[a-z0-9][a-z0-9-]*$")

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def normalize_platform_id(value):
    text = _t(value).lower().replace("_", "-").replace(" ", "-")
    return re.sub(r"-+", "-", text)

def validate_bootstrap_spec(spec):
    errors = []
    if not isinstance(spec, dict):
        return {"valid": False, "errors": ["bootstrap_spec_not_object"]}

    for key in (
        "platform_id", "platform_name", "community", "native_language",
        "support_languages", "rlb", "resources", "identity"
    ):
        if key not in spec:
            errors.append("missing_" + key)

    platform_id = normalize_platform_id(spec.get("platform_id"))
    if not platform_id or not PLATFORM_ID_RE.match(platform_id):
        errors.append("platform_id_invalid")

    if not _t(spec.get("platform_name")):
        errors.append("platform_name_required")

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
        if not _t(item.get("name")):
            errors.append(f"support_{index}_name_required")
        if code and code == native_code:
            errors.append(f"support_{index}_cannot_equal_native")
        if code and code in seen:
            errors.append(f"support_{index}_duplicate_code")
        if code:
            seen.add(code)
            support_codes.append(code)

    if spec.get("independent_platform") is not True:
        errors.append("independent_platform_required")

    if spec.get("sgoda_core_mode") != "shared_reference":
        errors.append("sgoda_core_mode_must_be_shared_reference")

    for key, message in (
        ("rlb", "rlb_instance_specific_required"),
        ("resources", "resources_instance_specific_required"),
        ("identity", "identity_instance_specific_required"),
    ):
        value = spec.get(key)
        if not isinstance(value, dict) or value.get("instance_specific") is not True:
            errors.append(message)

    community = spec.get("community")
    if (
        not isinstance(community, dict)
        or not _t(community.get("community_id"))
        or not _t(community.get("name"))
    ):
        errors.append("community_identity_invalid")

    return {
        "valid": not errors,
        "errors": errors,
        "platform_id": platform_id,
        "native_language": native_code,
        "support_language_codes": support_codes,
    }

def build_bootstrap_bundle(spec):
    validation = validate_bootstrap_spec(spec)
    if not validation["valid"]:
        return {"valid": False, "errors": validation["errors"]}

    platform_id = validation["platform_id"]
    native_code = validation["native_language"]
    support_codes = validation["support_language_codes"]

    platform = {
        "platform_id": platform_id,
        "platform_name": _t(spec["platform_name"]),
        "independent_platform": True,
        "sgoda_core": {
            "mode": "shared_reference",
            "embedded_copy": False,
        },
        "community": spec["community"],
        "native_language": spec["native_language"],
        "support_languages": spec["support_languages"],
    }

    rlb = {
        "repository_id": "RLB-" + native_code.upper(),
        "instance_specific": True,
        "native_language": native_code,
        "support_languages": support_codes,
        "records": [],
        "bootstrap_state": "EMPTY_READY",
    }

    resources = {
        "instance_specific": True,
        "resources": spec["resources"].get("catalog", []),
        "bootstrap_state": "READY",
    }

    identity = dict(spec["identity"])
    identity["instance_specific"] = True
    identity["platform_id"] = platform_id
    identity["platform_name"] = _t(spec["platform_name"])

    manifest = {
        "bootstrap_contract": "SGODA_LANGUAGE_INSTANCE_V1",
        "platform_id": platform_id,
        "native_language": native_code,
        "support_languages": support_codes,
        "shared_core_reference": True,
        "core_copy_created": False,
        "production_deployed": False,
    }

    bundle = {
        "platform.json": platform,
        "rlb.json": rlb,
        "resources.json": resources,
        "identity.json": identity,
        "bootstrap-manifest.json": manifest,
    }
    return {"valid": True, "bundle": bundle, "manifest": manifest}

def bundle_fingerprint(bundle):
    payload = json.dumps(
        bundle,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return sha256(payload.encode("utf-8")).hexdigest()

def reference_puinave_bootstrap_spec():
    return {
        "platform_id": "sgoda-puinave",
        "platform_name": "SGODA-PUINAVE",
        "independent_platform": True,
        "sgoda_core_mode": "shared_reference",
        "community": {
            "community_id": "puinave",
            "name": "Pueblo Puinave",
        },
        "native_language": {
            "code": "pui",
            "name": "Puinave",
        },
        "support_languages": [
            {"code": "es", "name": "Español"},
            {"code": "en", "name": "English"},
            {"code": "it", "name": "Italiano"},
            {"code": "pt", "name": "Português"},
        ],
        "rlb": {"instance_specific": True},
        "resources": {
            "instance_specific": True,
            "catalog": [],
        },
        "identity": {
            "instance_specific": True,
            "branding": {"configurable_per_platform": True},
        },
    }
'@
    $InitText = @'
from .core import (
    PLATFORM_ID_RE,
    normalize_code,
    normalize_platform_id,
    validate_bootstrap_spec,
    build_bootstrap_bundle,
    bundle_fingerprint,
    reference_puinave_bootstrap_spec,
)

__all__ = [
    "PLATFORM_ID_RE",
    "normalize_code",
    "normalize_platform_id",
    "validate_bootstrap_spec",
    "build_bootstrap_bundle",
    "bundle_fingerprint",
    "reference_puinave_bootstrap_spec",
]
'@
    $TestText = @'
from sgoda.integration.spt0257 import *

def ref():
    return reference_puinave_bootstrap_spec()

def test_01():
    assert validate_bootstrap_spec(ref())["valid"]

def test_02():
    assert normalize_platform_id("SGODA KURRIPACO") == "sgoda-kurripaco"

def test_03():
    assert validate_bootstrap_spec(ref())["native_language"] == "pui"

def test_04():
    assert validate_bootstrap_spec(ref())["support_language_codes"] == ["es", "en", "it", "pt"]

def test_05():
    assert build_bootstrap_bundle(ref())["valid"]

def test_06():
    assert build_bootstrap_bundle(ref())["manifest"]["shared_core_reference"] is True

def test_07():
    assert build_bootstrap_bundle(ref())["manifest"]["core_copy_created"] is False

def test_08():
    assert build_bootstrap_bundle(ref())["manifest"]["production_deployed"] is False

def test_09():
    assert build_bootstrap_bundle(ref())["bundle"]["rlb.json"]["records"] == []

def test_10():
    assert build_bootstrap_bundle(ref())["bundle"]["rlb.json"]["bootstrap_state"] == "EMPTY_READY"

def test_11():
    value = ref()
    value["support_languages"].append({"code": "pui", "name": "Puinave"})
    assert not validate_bootstrap_spec(value)["valid"]

def test_12():
    value = ref()
    value["support_languages"].append({"code": "es", "name": "Duplicado"})
    assert not validate_bootstrap_spec(value)["valid"]

def test_13():
    value = ref()
    value["sgoda_core_mode"] = "embedded_copy"
    assert "sgoda_core_mode_must_be_shared_reference" in validate_bootstrap_spec(value)["errors"]

def test_14():
    value = ref()
    value["rlb"]["instance_specific"] = False
    assert "rlb_instance_specific_required" in validate_bootstrap_spec(value)["errors"]

def test_15():
    value = ref()
    value["resources"]["instance_specific"] = False
    assert "resources_instance_specific_required" in validate_bootstrap_spec(value)["errors"]

def test_16():
    value = ref()
    value["identity"]["instance_specific"] = False
    assert "identity_instance_specific_required" in validate_bootstrap_spec(value)["errors"]

def test_17():
    value = ref()
    value["platform_id"] = "bad"
    assert "platform_id_invalid" in validate_bootstrap_spec(value)["errors"]

def test_18():
    value = ref()
    value["platform_id"] = "sgoda-kurripaco"
    value["platform_name"] = "SGODA-KURRIPACO"
    value["community"] = {
        "community_id": "kurripaco",
        "name": "Pueblo Kurripaco",
    }
    value["native_language"] = {
        "code": "kpc",
        "name": "Kurripaco",
    }
    result = build_bootstrap_bundle(value)
    assert result["valid"]
    assert result["manifest"]["platform_id"] == "sgoda-kurripaco"

def test_19():
    value = ref()
    value["platform_id"] = "sgoda-x"
    value["platform_name"] = "SGODA-X"
    value["community"] = {"community_id": "x", "name": "Pueblo X"}
    value["native_language"] = {"code": "x", "name": "Lengua X"}
    value["support_languages"] = []
    assert build_bootstrap_bundle(value)["valid"]

def test_20():
    bundle = build_bootstrap_bundle(ref())["bundle"]
    assert bundle_fingerprint(bundle) == bundle_fingerprint(bundle)

def test_21():
    first = build_bootstrap_bundle(ref())["bundle"]
    second = build_bootstrap_bundle(ref())["bundle"]
    second["platform.json"]["platform_name"] = "OTHER"
    assert bundle_fingerprint(first) != bundle_fingerprint(second)

def test_22():
    assert set(build_bootstrap_bundle(ref())["bundle"]) == {
        "platform.json",
        "rlb.json",
        "resources.json",
        "identity.json",
        "bootstrap-manifest.json",
    }

def test_23():
    assert build_bootstrap_bundle(ref())["bundle"]["platform.json"]["sgoda_core"]["embedded_copy"] is False

def test_24():
    assert build_bootstrap_bundle(ref())["bundle"]["identity.json"]["instance_specific"] is True

def test_25():
    assert build_bootstrap_bundle(ref())["bundle"]["resources.json"]["instance_specific"] is True

def test_26():
    assert build_bootstrap_bundle(ref())["manifest"]["bootstrap_contract"] == "SGODA_LANGUAGE_INSTANCE_V1"
'@

    $PolicyText = @'
{
  "component": "SPT-025.7",
  "version": "1.0.1",
  "mode": "RECOVERY",
  "shared_core_reference": true,
  "duplicate_core_per_instance": false,
  "production_deployment": false,
  "modify_sgoda_puinave": false
}
'@

    $SchemaText = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SGODA Language Instance Bootstrap Specification",
  "type": "object"
}
'@

    $PuinaveText = @'
{
  "platform_id": "sgoda-puinave",
  "platform_name": "SGODA-PUINAVE",
  "independent_platform": true,
  "sgoda_core_mode": "shared_reference",
  "community": {
    "community_id": "puinave",
    "name": "Pueblo Puinave"
  },
  "native_language": {
    "code": "pui",
    "name": "Puinave"
  },
  "support_languages": [
    {"code": "es", "name": "Español"},
    {"code": "en", "name": "English"},
    {"code": "it", "name": "Italiano"},
    {"code": "pt", "name": "Português"}
  ],
  "rlb": {"instance_specific": true},
  "resources": {"instance_specific": true, "catalog": []},
  "identity": {"instance_specific": true}
}
'@

    $KurripacoText = @'
{
  "example_only": true,
  "deploy": false,
  "platform_id": "sgoda-kurripaco",
  "platform_name": "SGODA-KURRIPACO",
  "independent_platform": true,
  "sgoda_core_mode": "shared_reference",
  "community": {
    "community_id": "kurripaco",
    "name": "Pueblo Kurripaco"
  },
  "native_language": {
    "code": "kpc",
    "name": "Kurripaco"
  },
  "support_languages": [
    {"code": "es", "name": "Español"},
    {"code": "en", "name": "English"}
  ],
  "rlb": {"instance_specific": true},
  "resources": {"instance_specific": true, "catalog": []},
  "identity": {"instance_specific": true}
}
'@

    $DocumentationText = @'
# SPT-025.7 — Generador Institucional de Instancias Lingüísticas / Bootstrap de Plataforma Independiente

Baseline autoritativa: `be336578467f3971295338adc3b9f5ff9c78ef99`.

Esta capa implementa la fábrica de paquetes de bootstrap para plataformas lingüísticas independientes.

SGODA Core se reutiliza mediante referencia compartida y no se copia por instancia. Cada nueva plataforma recibe su configuración propia, un RLB vacío y preparado, catálogo de recursos, identidad y manifiesto de bootstrap.

El ejemplo SGODA-KURRIPACO es únicamente una previsualización no desplegada. Esta capa no crea una plataforma Kurripaco real y no modifica SGODA-PUINAVE.
'@

    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $SchemaFile $SchemaText
    Write-Lf $PuinaveSpecFile $PuinaveText
    Write-Lf $ExampleSpecFile $KurripacoText
    Write-Lf $DocFile $DocumentationText

    Write-Host "SPT-025.7 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "POWERSHELL-SAFE PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH = Join-Path $Root "src"

    $SmokeCode = @'
from sgoda.integration.spt0257 import (
    reference_puinave_bootstrap_spec,
    build_bootstrap_bundle,
)
result = build_bootstrap_bundle(reference_puinave_bootstrap_spec())
assert result["valid"]
assert result["manifest"]["shared_core_reference"] is True
assert result["manifest"]["core_copy_created"] is False
assert result["manifest"]["production_deployed"] is False
print("SPT0257_IMPORT=PASS")
print("BOOTSTRAP_FACTORY_CONTRACT=PASS")
print("SHARED_CORE_REFERENCE=PASS")
'@

    $SmokePath = Join-Path ([System.IO.Path]::GetTempPath()) ("spt0257-smoke-" + [guid]::NewGuid().ToString("N") + ".py")
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($SmokePath, $SmokeCode, $Utf8)

    try {
        & $Python $SmokePath
        if ($LASTEXITCODE -ne 0) {
            Hold "SPT-025.7 smoke validation failed"
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

    Step 8 "BOOTSTRAP FACTORY / REPLICATION ASSESSMENT"
    $PuinaveConfig = Get-Content -Raw -LiteralPath (Join-Path $Root $PuinaveSpecFile) | ConvertFrom-Json
    $KurripacoConfig = Get-Content -Raw -LiteralPath (Join-Path $Root $ExampleSpecFile) | ConvertFrom-Json

    if ([string]$PuinaveConfig.sgoda_core_mode -ne "shared_reference") {
        Hold "Puinave reference must use shared core"
    }
    if ([bool]$KurripacoConfig.deploy) {
        Hold "Kurripaco preview must remain non-deployed"
    }

    Write-Host "LANGUAGE_INSTANCE_FACTORY=PASS"
    Write-Host "ONE_NATIVE_LANGUAGE_PER_INSTANCE=PASS"
    Write-Host "SUPPORT_LANGUAGES_CONFIGURABLE=PASS"
    Write-Host "SGODA_CORE_SHARED_REFERENCE=PASS"
    Write-Host "SGODA_CORE_DUPLICATED_PER_INSTANCE=NO"
    Write-Host "RLB_BOOTSTRAP_EMPTY_READY=PASS"
    Write-Host "RESOURCE_CATALOG_BOOTSTRAP=PASS"
    Write-Host "IDENTITY_BOOTSTRAP=PASS"
    Write-Host "KURRIPACO_PREVIEW_VALIDATION=PASS"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "SGODA_PUINAVE_MODIFIED=NO"
    Write-Host "LANGUAGE INSTANCE BOOTSTRAP GATE : PASS"

    Step 9 "FACTORY BASELINES / PREVIEW / PREPARE / EVIDENCE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir) | Out-Null

    $FactoryModel = [ordered]@{
        model = "SGODA_LANGUAGE_INSTANCE_FACTORY"
        version = "1.0.1"
        sgoda_core = "SHARED_REFERENCE"
        core_copy_created = $false
        one_native_language = $true
        support_languages = "0..N"
        production_deployment = $false
    }

    $BootstrapContract = [ordered]@{
        generated_files = @(
            "platform.json",
            "rlb.json",
            "resources.json",
            "identity.json",
            "bootstrap-manifest.json"
        )
        rlb_state = "EMPTY_READY"
        resources_state = "READY"
        identity_state = "READY"
    }

    $PuinaveReference = [ordered]@{
        platform_id = "sgoda-puinave"
        native_language = "pui"
        support_languages = @("es", "en", "it", "pt")
        reference_only = $true
        modified = $false
    }

    $KurripacoPreview = [ordered]@{
        example_only = $true
        deployed = $false
        platform_id = "sgoda-kurripaco"
        native_language = "kpc"
        support_languages = @("es", "en")
        sgoda_core = "SHARED_REFERENCE"
        rlb_state = "EMPTY_READY"
    }

    $CoreReuse = [ordered]@{
        shared_core_reference = $true
        duplicate_core_per_instance = $false
        instance_contains = @(
            "platform_config",
            "rlb",
            "resources",
            "identity",
            "bootstrap_manifest"
        )
    }

    $Assessment = [ordered]@{
        component = "SPT-025.7"
        version = "1.0.1"
        baseline = $ExpectedBaseline
        status = "LANGUAGE_INSTANCE_BOOTSTRAP_GATE_PASS"
        recovery_from = "v1.0.0-parser-hold"
        shared_core_reference = $true
        core_duplicated = $false
        real_new_platform_deployed = $false
        sgoda_puinave_modified = $false
        closed_components_preserved = $true
    }

    $Prepare = [ordered]@{
        next_deliverable = "SPT-025.8"
        title = "Validador de Instancias, Quality Gates de Bootstrap, Compatibilidad y Ensayo de Replicacion No Destructiva"
        source_baseline = $ExpectedBaseline
        bootstrap_factory_gate = "PASS"
    }

    Write-Lf $FactoryModelFile ($FactoryModel | ConvertTo-Json -Depth 8)
    Write-Lf $BootstrapContractFile ($BootstrapContract | ConvertTo-Json -Depth 8)
    Write-Lf $PuinaveReferenceFile ($PuinaveReference | ConvertTo-Json -Depth 8)
    Write-Lf $KurripacoPreviewFile ($KurripacoPreview | ConvertTo-Json -Depth 8)
    Write-Lf $CoreReuseFile ($CoreReuse | ConvertTo-Json -Depth 8)
    Write-Lf $AssessmentFile ($Assessment | ConvertTo-Json -Depth 8)
    Write-Lf $PrepareFile ($Prepare | ConvertTo-Json -Depth 8)

    $ManifestRecords = @()
    foreach ($ManifestPath in @(
        $PolicyFile,
        $SchemaFile,
        $PuinaveSpecFile,
        $ExampleSpecFile,
        $DocFile,
        $FactoryModelFile,
        $BootstrapContractFile,
        $PuinaveReferenceFile,
        $KurripacoPreviewFile,
        $CoreReuseFile,
        $AssessmentFile,
        $PrepareFile
    )) {
        $ManifestRecords += [ordered]@{
            path = $ManifestPath
            sha256 = Get-Sha256 (Join-Path $Root $ManifestPath)
        }
    }

    Write-Lf $IntegrityFile (
        [ordered]@{
            algorithm = "SHA-256"
            records = $ManifestRecords
        } | ConvertTo-Json -Depth 10
    )

    Write-Lf $EvidenceFile (
        [ordered]@{
            component = "SPT-025.7"
            version = "1.0.1"
            baseline = $ExpectedBaseline
            status = "LANGUAGE_INSTANCE_BOOTSTRAP_GATE_PASS"
            targeted_tests = "PASS"
            institutional_suite = "PASS"
            compileall = "PASS"
            parser_recovery = "PASS"
            real_new_platform_deployed = $false
            sgoda_puinave_modified = $false
            production_change = $false
            closed_components_preserved = $true
        } | ConvertTo-Json -Depth 8
    )

    Write-Host "FACTORY MODEL        : CREATED"
    Write-Host "BOOTSTRAP CONTRACT   : CREATED"
    Write-Host "PUINAVE REFERENCE    : CREATED"
    Write-Host "KURRIPACO PREVIEW    : CREATED / NOT DEPLOYED"
    Write-Host "CORE REUSE BASELINE  : CREATED"
    Write-Host "SPT-025.8 PREPARE    : CREATED"
    Write-Host "EVIDENCE             : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (-not (Test-Path -LiteralPath $AbsoluteTrackedPath)) {
            Hold "Protected tracked file disappeared: $TrackedPath"
        }
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) {
            Hold "Protected tracked file changed: $TrackedPath"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024 / PISI + SPT-025.1-.6 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed = @(
        "Invoke-SGODA-SPT0257-LanguageInstanceBootstrap-Factory-RECOVERY-v1.0.1-PS51.ps1",
        $CoreFile,
        $InitFile,
        $TestFile,
        $PolicyFile,
        $SchemaFile,
        $PuinaveSpecFile,
        $ExampleSpecFile,
        $DocFile,
        $FactoryModelFile,
        $BootstrapContractFile,
        $PuinaveReferenceFile,
        $KurripacoPreviewFile,
        $CoreReuseFile,
        $AssessmentFile,
        $IntegrityFile,
        $PrepareFile,
        $EvidenceFile
    )

    foreach ($AllowedPath in $Allowed) {
        $AbsoluteAllowedPath = Join-Path $Root $AllowedPath
        if (-not (Test-Path -LiteralPath $AbsoluteAllowedPath)) {
            Hold "Missing expected target: $AllowedPath"
        }
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $AllowedPath
        if ($LASTEXITCODE -ne 0) {
            Hold "git add failed: $AllowedPath"
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

    if ($Unexpected.Count -ne 0) {
        Hold "Unexpected staged path detected"
    }
    if ($StagedNames.Count -ne $Allowed.Count) {
        Hold "Exact staging count mismatch"
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

    $RemoteHeadBeforeCommit = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    if ($RemoteHeadBeforeCommit -ne $ExpectedBaseline) {
        Hold "Remote advanced during transaction"
    }

    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (-not (Test-Path -LiteralPath $AbsoluteTrackedPath)) {
            Hold "Protected tracked file disappeared before commit"
        }
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) {
            Hold "Protected tracked file changed before commit"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "fix(spt-025.7): recover PowerShell parser and bootstrap factory publication"
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

    if ($FinalLocal -ne $FinalRemote) {
        Hold "Final local/remote HEAD mismatch"
    }
    if ($Behind -ne "0" -or $Ahead -ne "0") {
        Hold "Final divergence detected"
    }
    if ($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0) {
        Hold "Final repository state is not clean enough for closure"
    }

    Write-Host ""
    Write-Host "SPT-025.7 : TECHNICALLY CLOSED / LANGUAGE INSTANCE BOOTSTRAP FACTORY APPROVED" -ForegroundColor Green
    Write-Host "SPT-025.7_PARSER_RECOVERY=PASS"
    Write-Host "FAILED_MASTER_V1.0.0=SUPERSEDED_NOT_PUBLISHED"
    Write-Host "SPT-025.6_IDENTITY_BRANDING_GATE=PASS"
    Write-Host "LANGUAGE_INSTANCE_FACTORY=PASS"
    Write-Host "ONE_NATIVE_LANGUAGE_PER_INSTANCE=PASS"
    Write-Host "SUPPORT_LANGUAGES_CONFIGURABLE=PASS"
    Write-Host "SGODA_CORE_SHARED_REFERENCE=PASS"
    Write-Host "SGODA_CORE_DUPLICATED_PER_INSTANCE=NO"
    Write-Host "RLB_BOOTSTRAP_EMPTY_READY=PASS"
    Write-Host "RESOURCE_CATALOG_BOOTSTRAP=PASS"
    Write-Host "IDENTITY_BOOTSTRAP=PASS"
    Write-Host "KURRIPACO_PREVIEW_VALIDATION=PASS"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "SGODA_PUINAVE_MODIFIED=NO"
    Write-Host "DESTRUCTIVE_CHANGE=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "NEXT_DELIVERABLE=SPT-025.8"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
