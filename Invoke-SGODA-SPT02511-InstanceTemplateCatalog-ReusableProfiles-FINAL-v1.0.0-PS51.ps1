#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "12d228f423d553f12eebccfee506926975c392d1"
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$ReqAssessment = "artifacts/development/SPT-025.10-v1.0.0/master-registry-lifecycle-assessment.json"
$ReqPrepare = "artifacts/development/SPT-025.10-v1.0.0/spt02511-prepare.json"
$ReqContinuity = "artifacts/development/SPT-025.RepositoryContinuityAudit-v1.0.0/repository-continuity-assessment.json"

$CoreFile = "src/sgoda/integration/spt02511/core.py"
$InitFile = "src/sgoda/integration/spt02511/__init__.py"
$TestFile = "tests/integration/test_spt02511_instance_template_catalog_profiles.py"
$PolicyFile = "config/integration/spt02511/instance-template-profile-catalog-policy.json"
$TemplateSchemaFile = "config/integration/spt02511/instance-template.schema.json"
$ProfileSchemaFile = "config/integration/spt02511/configuration-profile.schema.json"
$DocFile = "docs/06_Tecnologia/SPT-025/SPT-025.11/SGD-SPT025.11-Catalogo-Plantillas-Perfiles-Configuracion-Reutilizables.md"

$ArtifactDir = "artifacts/development/SPT-025.11-v1.0.0"
$TemplateCatalogFile = "$ArtifactDir/master-instance-template-catalog.json"
$ProfileCatalogFile = "$ArtifactDir/master-configuration-profile-catalog.json"
$ExampleTemplateFile = "$ArtifactDir/generic-instance-template-example.json"
$ExampleProfileFile = "$ArtifactDir/generic-configuration-profile-example.json"
$CompatibilityFile = "$ArtifactDir/template-profile-compatibility-matrix.json"
$RulesFile = "$ArtifactDir/reusable-configuration-rules.json"
$AssessmentFile = "$ArtifactDir/template-profile-catalog-assessment.json"
$IntegrityFile = "$ArtifactDir/template-profile-catalog-sha256-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"
$PrepareFile = "$ArtifactDir/spt02512-prepare.json"

function Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number, $Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-025.11 : HOLD" -ForegroundColor Red
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
    if (-not $Root) { Hold "Not inside Git repository" }
    Set-Location $Root

    $Python = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $Python)) { $Python = "python.exe" }

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

    if ($LocalHead -ne $ExpectedBaseline -or $RemoteHead -ne $ExpectedBaseline) { Hold "Authoritative baseline mismatch" }
    if ($Staged.Count -ne 0 -or $DeletedTracked.Count -ne 0) { Hold "Unsafe staged/deleted state" }

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-025.1-.10 + REPOSITORY AUDIT : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-025.10 GATE / SPT-025.11 PREPARE / CONTINUITY"
    $RequiredInputs = @($ReqAssessment,$ReqPrepare,$ReqContinuity)
    $Missing = @($RequiredInputs | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Root $_)) })
    Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS  : $($Missing.Count)"
    if ($Missing.Count -ne 0) { Hold "Missing SPT-025.11 prerequisites" }

    $Previous = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqAssessment) | ConvertFrom-Json
    $Prepare = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqPrepare) | ConvertFrom-Json
    $Continuity = Get-Content -Raw -LiteralPath (Join-Path $Root $ReqContinuity) | ConvertFrom-Json

    if ([string]$Previous.status -ne "MASTER_INSTANCE_REGISTRY_LIFECYCLE_GATE_PASS") { Hold "SPT-025.10 gate is not PASS" }
    if ([string]$Prepare.next_deliverable -ne "SPT-025.11") { Hold "SPT-025.11 PREPARE contract mismatch" }
    if ([string]$Prepare.spt02510_master_registry_gate -ne "PASS") { Hold "SPT-025.11 PREPARE gate is not PASS" }
    if ([string]$Continuity.status -ne "REPOSITORY_CONTINUITY_GATE_PASS") { Hold "Repository continuity gate is not PASS" }

    Write-Host "SPT-025.10 MASTER REGISTRY GATE : PASS"
    Write-Host "SPT-025.11 PREPARE CONTRACT     : PASS"
    Write-Host "REPOSITORY CONTINUITY GATE      : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
    $Freeze = @{}
    foreach ($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (Test-Path -LiteralPath $AbsoluteTrackedPath) { $Freeze[$TrackedPath] = Get-Sha256 $AbsoluteTrackedPath }
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "TEMPLATE / PROFILE CATALOG DISCOVERY"
    Write-Host "CATALOG MODEL                 : GENERIC / LANGUAGE-NEUTRAL"
    Write-Host "NATIVE LANGUAGE               : EXACTLY 1 / CONFIGURABLE"
    Write-Host "SUPPORT LANGUAGES             : 0..N / CONFIGURABLE"
    Write-Host "HARD-CODED SUPPORT LANGUAGES  : NO"
    Write-Host "TEMPLATE VERSIONING           : REQUIRED"
    Write-Host "PROFILE VERSIONING            : REQUIRED"
    Write-Host "TEMPLATE/PROFILE COMPATIBILITY: REQUIRED"
    Write-Host "EXAMPLE PROFILES              : EVIDENCE ONLY"
    Write-Host "AUTO DEPLOYMENT               : NO"
    Write-Host "PRODUCTION CHANGE             : NO"

    Step 5 "IMPLEMENT SPT-025.11 TEMPLATE / PROFILE CATALOG"
    $CoreText = @'
from hashlib import sha256
import json
import re

ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")

def _t(value):
    return str(value or "").strip()

def normalize_id(value):
    return _t(value).lower().replace(" ", "-").replace("_", "-")

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def validate_template(template):
    errors = []
    if not isinstance(template, dict):
        return {"valid": False, "errors": ["template_not_object"]}
    for key in ("template_id","version","native_language","support_languages","features","resources","identity","governance"):
        if key not in template:
            errors.append("missing_" + key)

    tid = normalize_id(template.get("template_id"))
    if not ID_RE.match(tid or ""):
        errors.append("template_id_invalid")
    if not VERSION_RE.match(_t(template.get("version"))):
        errors.append("template_version_invalid")

    native = template.get("native_language")
    if not isinstance(native, dict) or native.get("mode") != "CONFIGURABLE_EXACTLY_ONE":
        errors.append("native_language_contract_invalid")

    support = template.get("support_languages")
    if not isinstance(support, dict):
        errors.append("support_languages_contract_invalid")
    else:
        if support.get("mode") != "CONFIGURABLE_0_TO_N":
            errors.append("support_languages_mode_invalid")
        if support.get("hard_coded") is not False:
            errors.append("hard_coded_support_languages_forbidden")

    for key, msg in (
        ("resources","resources_configurable_required"),
        ("identity","identity_configurable_required"),
        ("features","features_configurable_required"),
    ):
        value = template.get(key)
        if not isinstance(value, dict) or value.get("configurable") is not True:
            errors.append(msg)

    governance = template.get("governance")
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

    return {"valid": not errors, "errors": errors, "template_id": tid}

def validate_profile(profile):
    errors = []
    if not isinstance(profile, dict):
        return {"valid": False, "errors": ["profile_not_object"]}
    for key in ("profile_id","version","template_id","native_language","support_languages","resource_profile","identity_profile","governance"):
        if key not in profile:
            errors.append("missing_" + key)

    pid = normalize_id(profile.get("profile_id"))
    tid = normalize_id(profile.get("template_id"))
    if not ID_RE.match(pid or ""):
        errors.append("profile_id_invalid")
    if not ID_RE.match(tid or ""):
        errors.append("template_id_invalid")
    if not VERSION_RE.match(_t(profile.get("version"))):
        errors.append("profile_version_invalid")

    native = profile.get("native_language")
    native_code = normalize_code(native.get("code")) if isinstance(native, dict) else ""
    if not native_code:
        errors.append("native_language_required")

    supports = profile.get("support_languages")
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
        elif code == native_code:
            errors.append(f"support_{index}_equals_native")
        elif code in seen:
            errors.append(f"support_{index}_duplicate")
        else:
            seen.add(code)
            support_codes.append(code)

    governance = profile.get("governance")
    if not isinstance(governance, dict):
        errors.append("governance_not_object")
    else:
        if governance.get("example_only") not in (True, False):
            errors.append("example_only_required")
        if governance.get("auto_deploy") is not False:
            errors.append("auto_deploy_forbidden")
        if governance.get("production_change") is not False:
            errors.append("production_change_forbidden")

    return {
        "valid": not errors,
        "errors": errors,
        "profile_id": pid,
        "template_id": tid,
        "native_language": native_code,
        "support_languages": support_codes,
    }

def template_profile_compatible(template, profile):
    t = validate_template(template)
    p = validate_profile(profile)
    errors = []
    if not t["valid"]:
        errors.extend("template_" + e for e in t["errors"])
    if not p["valid"]:
        errors.extend("profile_" + e for e in p["errors"])
    if t["valid"] and p["valid"] and t["template_id"] != p["template_id"]:
        errors.append("profile_template_mismatch")
    return {"compatible": not errors, "errors": errors}

def fingerprint(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def build_catalog(templates, profiles):
    if not isinstance(templates, list) or not isinstance(profiles, list):
        return {"valid": False, "errors": ["catalog_inputs_not_lists"]}
    errors = []
    template_ids = set()
    profile_ids = set()
    template_records = []
    profile_records = []

    for i, template in enumerate(templates):
        result = validate_template(template)
        if not result["valid"]:
            errors.extend(f"template_{i}_{e}" for e in result["errors"])
            continue
        if result["template_id"] in template_ids:
            errors.append(f"template_{i}_duplicate_id")
            continue
        template_ids.add(result["template_id"])
        template_records.append({
            "template_id": result["template_id"],
            "version": template["version"],
            "fingerprint": fingerprint(template),
        })

    for i, profile in enumerate(profiles):
        result = validate_profile(profile)
        if not result["valid"]:
            errors.extend(f"profile_{i}_{e}" for e in result["errors"])
            continue
        if result["profile_id"] in profile_ids:
            errors.append(f"profile_{i}_duplicate_id")
            continue
        profile_ids.add(result["profile_id"])
        profile_records.append({
            "profile_id": result["profile_id"],
            "template_id": result["template_id"],
            "version": profile["version"],
            "native_language": result["native_language"],
            "support_languages": result["support_languages"],
            "example_only": profile["governance"]["example_only"],
            "fingerprint": fingerprint(profile),
        })

    for profile in profiles:
        if isinstance(profile, dict):
            tid = normalize_id(profile.get("template_id"))
            if tid and tid not in template_ids:
                errors.append("profile_references_unknown_template")

    return {
        "valid": not errors,
        "errors": errors,
        "catalog_contract": "SGODA_INSTANCE_TEMPLATE_PROFILE_CATALOG_V1",
        "templates": template_records,
        "profiles": profile_records,
        "real_instance_count": 0,
        "example_profile_count": sum(1 for x in profile_records if x["example_only"]),
    }

def generic_template():
    return {
        "template_id": "sgoda-language-platform-standard",
        "version": "1.0.0",
        "native_language": {"mode": "CONFIGURABLE_EXACTLY_ONE"},
        "support_languages": {"mode": "CONFIGURABLE_0_TO_N", "hard_coded": False},
        "features": {"configurable": True},
        "resources": {"configurable": True, "bible_optional": True},
        "identity": {"configurable": True},
        "governance": {
            "shared_core_reference": True,
            "duplicate_core": False,
            "auto_deploy": False,
            "production_change": False,
        },
    }

def generic_example_profile():
    return {
        "profile_id": "example-language-profile",
        "version": "1.0.0",
        "template_id": "sgoda-language-platform-standard",
        "native_language": {"code": "qaa", "name": "Example Native Language"},
        "support_languages": [
            {"code": "es", "name": "Español"},
            {"code": "en", "name": "English"},
            {"code": "it", "name": "Italiano"},
            {"code": "pt", "name": "Português"},
        ],
        "resource_profile": {"bible": {"enabled": False, "url": None}},
        "identity_profile": {"community": "Example Community", "branding": "configurable"},
        "governance": {
            "example_only": True,
            "auto_deploy": False,
            "production_change": False,
        },
    }
'@
    $InitText = @'
from .core import (
    ID_RE,
    VERSION_RE,
    normalize_id,
    normalize_code,
    validate_template,
    validate_profile,
    template_profile_compatible,
    fingerprint,
    build_catalog,
    generic_template,
    generic_example_profile,
)

__all__ = [
    "ID_RE",
    "VERSION_RE",
    "normalize_id",
    "normalize_code",
    "validate_template",
    "validate_profile",
    "template_profile_compatible",
    "fingerprint",
    "build_catalog",
    "generic_template",
    "generic_example_profile",
]
'@
    $TestText = @'
from sgoda.integration.spt02511 import *

def template():
    return generic_template()

def profile():
    return generic_example_profile()

def test_01(): assert validate_template(template())["valid"]
def test_02(): assert validate_profile(profile())["valid"]
def test_03(): assert template_profile_compatible(template(), profile())["compatible"]
def test_04(): assert build_catalog([template()], [profile()])["valid"]
def test_05(): assert build_catalog([template()], [profile()])["real_instance_count"] == 0
def test_06(): assert build_catalog([template()], [profile()])["example_profile_count"] == 1
def test_07(): assert template()["native_language"]["mode"] == "CONFIGURABLE_EXACTLY_ONE"
def test_08(): assert template()["support_languages"]["mode"] == "CONFIGURABLE_0_TO_N"
def test_09(): assert template()["support_languages"]["hard_coded"] is False
def test_10(): assert profile()["governance"]["example_only"] is True
def test_11(): assert profile()["governance"]["auto_deploy"] is False
def test_12(): assert profile()["governance"]["production_change"] is False
def test_13(): assert template()["governance"]["shared_core_reference"] is True
def test_14(): assert template()["governance"]["duplicate_core"] is False
def test_15(): assert profile()["native_language"]["code"] == "qaa"
def test_16(): assert [x["code"] for x in profile()["support_languages"]] == ["es","en","it","pt"]
def test_17():
    x=template(); x["support_languages"]["hard_coded"]=True; assert not validate_template(x)["valid"]
def test_18():
    x=template(); x["governance"]["duplicate_core"]=True; assert not validate_template(x)["valid"]
def test_19():
    x=template(); x["governance"]["auto_deploy"]=True; assert not validate_template(x)["valid"]
def test_20():
    x=template(); x["governance"]["production_change"]=True; assert not validate_template(x)["valid"]
def test_21():
    x=profile(); x["support_languages"].append({"code":"qaa","name":"bad"}); assert not validate_profile(x)["valid"]
def test_22():
    x=profile(); x["support_languages"].append({"code":"es","name":"dup"}); assert not validate_profile(x)["valid"]
def test_23():
    x=profile(); x["template_id"]="other-template"; assert not template_profile_compatible(template(),x)["compatible"]
def test_24():
    x=profile(); x["governance"]["auto_deploy"]=True; assert not validate_profile(x)["valid"]
def test_25():
    x=profile(); x["governance"]["production_change"]=True; assert not validate_profile(x)["valid"]
def test_26(): assert len(fingerprint(template())) == 64
def test_27(): assert fingerprint(template()) == fingerprint(template())
def test_28():
    a=template(); b=template(); b["version"]="1.0.1"; assert fingerprint(a) != fingerprint(b)
def test_29():
    assert not build_catalog([template(),template()],[profile()])["valid"]
def test_30():
    assert build_catalog([template()],[profile()])["catalog_contract"] == "SGODA_INSTANCE_TEMPLATE_PROFILE_CATALOG_V1"
def test_31(): assert normalize_id("SGODA Language Platform") == "sgoda-language-platform"
def test_32(): assert normalize_code("EN_us") == "en-us"
def test_33(): assert template()["resources"]["bible_optional"] is True
def test_34(): assert template()["identity"]["configurable"] is True
'@
    $PolicyText = @'
{
  "component": "SPT-025.11",
  "version": "1.0.0",
  "title": "Catalogo Institucional de Plantillas de Instancia y Perfiles de Configuracion Reutilizables",
  "authoritative_baseline": "12d228f423d553f12eebccfee506926975c392d1",
  "architecture": {
    "sgoda_core": "SHARED_REFERENCE",
    "one_native_language_per_platform": true,
    "support_languages": "0..N_CONFIGURABLE",
    "hard_coded_support_languages": false,
    "templates_language_neutral": true
  },
  "catalog": {
    "template_versioning_required": true,
    "profile_versioning_required": true,
    "sha256_required": true,
    "compatibility_gate_required": true,
    "examples_are_not_real_instances": true
  },
  "deployment": {
    "auto_deploy": false,
    "production_change": false,
    "real_platform_created": false
  },
  "repository": {
    "all_outputs_committed": true,
    "push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
    $TemplateSchemaText = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SGODA Instance Template",
  "type": "object",
  "required": ["template_id","version","native_language","support_languages","features","resources","identity","governance"]
}
'@
    $ProfileSchemaText = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SGODA Reusable Configuration Profile",
  "type": "object",
  "required": ["profile_id","version","template_id","native_language","support_languages","resource_profile","identity_profile","governance"]
}
'@
    $DocumentationText = @'
# SPT-025.11 — Catálogo Institucional de Plantillas de Instancia y Perfiles de Configuración Reutilizables

Baseline autoritativa: `12d228f423d553f12eebccfee506926975c392d1`.

SPT-025.11 consume obligatoriamente `artifacts/development/SPT-025.10-v1.0.0/spt02511-prepare.json`.

## Objetivo

Crear un catálogo institucional, reutilizable y neutral respecto de la lengua para definir plantillas de plataforma SGODA y perfiles de configuración sin desplegar plataformas reales.

La arquitectura permanece:

`SGODA Core → Motor de Instancias → una lengua nativa configurable → plataforma SGODA independiente → 0..N idiomas auxiliares configurables`.

Los idiomas auxiliares no están fijados en código. Español, inglés, italiano, portugués u otros pueden configurarse por instancia.

## Nombres y perfiles de ejemplo

Cualquier lengua o comunidad incluida en pruebas o evidencias es exclusivamente ilustrativa. No constituye una instancia real ni un destino de despliegue. Las referencias históricas a Kurripaco permanecen únicamente como evidencia técnica de capas previas.

## Catálogo

El catálogo gobierna:
- plantillas versionadas;
- perfiles versionados;
- compatibilidad plantilla/perfil;
- lengua nativa exactamente una por plataforma;
- 0..N idiomas auxiliares;
- recursos configurables, incluida Biblia opcional;
- identidad y branding configurables;
- SHA-256;
- referencia compartida a SGODA Core;
- no despliegue automático.

Todos los artefactos de SPT-025.11 deben quedar versionados y sincronizados en el repositorio oficial.

'@

    Write-Lf $CoreFile $CoreText
    Write-Lf $InitFile $InitText
    Write-Lf $TestFile $TestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $TemplateSchemaFile $TemplateSchemaText
    Write-Lf $ProfileSchemaFile $ProfileSchemaText
    Write-Lf $DocFile $DocumentationText

    Write-Host "SPT-025.11 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "POWERSHELL-SAFE PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH = Join-Path $Root "src"
    $SmokeCode = @'
from sgoda.integration.spt02511 import (
    generic_template, generic_example_profile,
    validate_template, validate_profile,
    template_profile_compatible, build_catalog,
)
t = generic_template()
p = generic_example_profile()
assert validate_template(t)["valid"]
assert validate_profile(p)["valid"]
assert template_profile_compatible(t,p)["compatible"]
catalog = build_catalog([t],[p])
assert catalog["valid"]
assert catalog["real_instance_count"] == 0
assert catalog["example_profile_count"] == 1
print("SPT02511_IMPORT=PASS")
print("TEMPLATE_CATALOG_CONTRACT=PASS")
print("PROFILE_CATALOG_CONTRACT=PASS")
print("TEMPLATE_PROFILE_COMPATIBILITY=PASS")
print("EXAMPLE_ONLY_NO_REAL_INSTANCE=PASS")
'@
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $SmokePath = Join-Path ([System.IO.Path]::GetTempPath()) ("spt02511-smoke-" + [guid]::NewGuid().ToString("N") + ".py")
    [System.IO.File]::WriteAllText($SmokePath,$SmokeCode,$Utf8)
    try {
        & $Python $SmokePath
        if ($LASTEXITCODE -ne 0) { Hold "SPT-025.11 smoke validation failed" }
    }
    finally {
        Remove-Item -LiteralPath $SmokePath -Force -ErrorAction SilentlyContinue
    }

    & $Python -m pytest -q $TestFile
    if ($LASTEXITCODE -ne 0) { Hold "Targeted tests failed" }
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
    & $Python -m pytest -q
    if ($LASTEXITCODE -ne 0) { Hold "Institutional suite failed" }
    Write-Host "FULL SUITE : PASS"

    & $Python -m compileall -q (Join-Path $Root "src")
    if ($LASTEXITCODE -ne 0) { Hold "compileall failed" }
    Write-Host "COMPILEALL : PASS"

    Step 8 "TEMPLATE / PROFILE CATALOG QUALITY GATE"
    $CatalogCode = @'
import json
from sgoda.integration.spt02511 import (
    generic_template, generic_example_profile,
    build_catalog, template_profile_compatible,
)
t = generic_template()
p = generic_example_profile()
result = {
    "template": t,
    "profile": p,
    "catalog": build_catalog([t],[p]),
    "compatibility": template_profile_compatible(t,p),
}
print(json.dumps(result,ensure_ascii=False))
'@
    $CatalogScript = Join-Path ([System.IO.Path]::GetTempPath()) ("spt02511-catalog-" + [guid]::NewGuid().ToString("N") + ".py")
    $CatalogOutput = Join-Path ([System.IO.Path]::GetTempPath()) ("spt02511-catalog-" + [guid]::NewGuid().ToString("N") + ".json")
    [System.IO.File]::WriteAllText($CatalogScript,$CatalogCode,$Utf8)
    try {
        & $Python $CatalogScript | Out-File -LiteralPath $CatalogOutput -Encoding utf8
        if ($LASTEXITCODE -ne 0) { Hold "Catalog assessment generation failed" }
        $CatalogResult = Get-Content -Raw -LiteralPath $CatalogOutput | ConvertFrom-Json
    }
    finally {
        Remove-Item -LiteralPath $CatalogScript -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $CatalogOutput -Force -ErrorAction SilentlyContinue
    }

    if (-not [bool]$CatalogResult.catalog.valid) { Hold "Template/profile catalog gate failed" }
    if (-not [bool]$CatalogResult.compatibility.compatible) { Hold "Template/profile compatibility gate failed" }
    if ([int]$CatalogResult.catalog.real_instance_count -ne 0) { Hold "Example profile incorrectly treated as real instance" }

    Write-Host "MASTER_TEMPLATE_CATALOG=PASS"
    Write-Host "MASTER_PROFILE_CATALOG=PASS"
    Write-Host "GENERIC_LANGUAGE_NEUTRAL_MODEL=PASS"
    Write-Host "ONE_NATIVE_LANGUAGE_PER_PLATFORM=PASS"
    Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS"
    Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO"
    Write-Host "TEMPLATE_VERSION_GOVERNANCE=PASS"
    Write-Host "PROFILE_VERSION_GOVERNANCE=PASS"
    Write-Host "TEMPLATE_PROFILE_COMPATIBILITY=PASS"
    Write-Host "EXAMPLE_PROFILE_REAL_INSTANCE=NO"
    Write-Host "AUTO_DEPLOYMENT=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "SPT-025.11 GLOBAL CATALOG GATE : PASS"

    Step 9 "WRITE CATALOGS / RULES / EVIDENCE / PREPARE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir) | Out-Null

    $TemplateCatalog = [ordered]@{
        contract = "SGODA_MASTER_INSTANCE_TEMPLATE_CATALOG_V1"
        templates = @($CatalogResult.catalog.templates)
        language_neutral = $true
        one_native_language_per_platform = $true
        support_languages = "0..N_CONFIGURABLE"
    }
    $ProfileCatalog = [ordered]@{
        contract = "SGODA_MASTER_CONFIGURATION_PROFILE_CATALOG_V1"
        profiles = @($CatalogResult.catalog.profiles)
        real_instance_count = 0
        example_profile_count = 1
    }
    $Compatibility = [ordered]@{
        template_id = [string]$CatalogResult.template.template_id
        profile_id = [string]$CatalogResult.profile.profile_id
        compatible = [bool]$CatalogResult.compatibility.compatible
        errors = @($CatalogResult.compatibility.errors)
    }
    $Rules = [ordered]@{
        native_language = "EXACTLY_ONE_CONFIGURABLE"
        support_languages = "0_TO_N_CONFIGURABLE"
        hard_coded_support_languages = $false
        bible_resource_optional_configurable = $true
        identity_configurable = $true
        shared_core_reference = $true
        duplicate_core = $false
        auto_deploy = $false
        production_change = $false
        example_names_are_evidence_only = $true
    }
    $Assessment = [ordered]@{
        component = "SPT-025.11"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        status = "TEMPLATE_PROFILE_CATALOG_GATE_PASS"
        generic_language_neutral = $true
        real_new_platform_deployed = $false
        example_profile_is_real_instance = $false
        historical_kurripaco_reference_is_real_instance = $false
        sgoda_puinave_modified = $false
        production_changed = $false
    }
    $Evidence = [ordered]@{
        component = "SPT-025.11"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        spt02510_gate = "PASS"
        prepare_consumed = $ReqPrepare
        targeted_tests = "PASS"
        institutional_suite = "PASS"
        compileall = "PASS"
        global_catalog_gate = "PASS"
        all_outputs_to_repository = $true
        closed_components_preserved = $true
    }
    $NextPrepare = [ordered]@{
        next_deliverable = "SPT-025.12"
        title = "Validador Institucional de Plantillas y Perfiles, Compatibilidad, Herencia y Quality Gates de Configuracion"
        source_baseline = $ExpectedBaseline
        spt02511_template_profile_catalog_gate = "PASS"
    }

    Write-Lf $TemplateCatalogFile ($TemplateCatalog | ConvertTo-Json -Depth 12)
    Write-Lf $ProfileCatalogFile ($ProfileCatalog | ConvertTo-Json -Depth 12)
    Write-Lf $ExampleTemplateFile ($CatalogResult.template | ConvertTo-Json -Depth 12)
    Write-Lf $ExampleProfileFile ($CatalogResult.profile | ConvertTo-Json -Depth 12)
    Write-Lf $CompatibilityFile ($Compatibility | ConvertTo-Json -Depth 12)
    Write-Lf $RulesFile ($Rules | ConvertTo-Json -Depth 12)
    Write-Lf $AssessmentFile ($Assessment | ConvertTo-Json -Depth 12)
    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 12)
    Write-Lf $PrepareFile ($NextPrepare | ConvertTo-Json -Depth 12)

    $IntegrityRecords = @()
    foreach ($P in @($TemplateCatalogFile,$ProfileCatalogFile,$ExampleTemplateFile,$ExampleProfileFile,$CompatibilityFile,$RulesFile,$AssessmentFile,$EvidenceFile,$PrepareFile)) {
        $IntegrityRecords += [ordered]@{ path=$P; sha256=Get-Sha256 (Join-Path $Root $P) }
    }
    Write-Lf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords} | ConvertTo-Json -Depth 12)

    Write-Host "MASTER TEMPLATE CATALOG : CREATED"
    Write-Host "MASTER PROFILE CATALOG  : CREATED"
    Write-Host "GENERIC TEMPLATE        : CREATED / EXAMPLE"
    Write-Host "GENERIC PROFILE         : CREATED / EXAMPLE ONLY"
    Write-Host "COMPATIBILITY MATRIX    : CREATED"
    Write-Host "REUSABLE RULES          : CREATED"
    Write-Host "SHA-256 MANIFEST        : CREATED"
    Write-Host "SPT-025.12 PREPARE      : CREATED"
    Write-Host "EVIDENCE                : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (-not (Test-Path -LiteralPath $AbsoluteTrackedPath)) { Hold ("Protected tracked file disappeared: " + $TrackedPath) }
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) { Hold ("Protected tracked file changed: " + $TrackedPath) }
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-025.1-.10 + REPOSITORY AUDIT : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed = @(
        "Invoke-SGODA-SPT02511-InstanceTemplateCatalog-ReusableProfiles-FINAL-v1.0.0-PS51.ps1",
        $CoreFile,
        $InitFile,
        $TestFile,
        $PolicyFile,
        $TemplateSchemaFile,
        $ProfileSchemaFile,
        $DocFile,
        $TemplateCatalogFile,
        $ProfileCatalogFile,
        $ExampleTemplateFile,
        $ExampleProfileFile,
        $CompatibilityFile,
        $RulesFile,
        $AssessmentFile,
        $IntegrityFile,
        $EvidenceFile,
        $PrepareFile
    )
    foreach ($AllowedPath in $Allowed) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $AllowedPath))) { Hold ("Missing expected target: " + $AllowedPath) }
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $AllowedPath
        if ($LASTEXITCODE -ne 0) { Hold ("git add failed: " + $AllowedPath) }
    }
    $StagedNames = @(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected = @($StagedNames | Where-Object { $Allowed -notcontains ($_ -replace "\\","/") })
    Write-Host "STAGED     : $($StagedNames.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"
    if ($Unexpected.Count -ne 0 -or $StagedNames.Count -ne $Allowed.Count) { Hold "Exact staging mismatch" }
    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"
    $Oversized = @()
    foreach ($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $BlobSizeText = @(& git.exe cat-file -s (":" + $TrackedPath) 2>$null)
        if ($LASTEXITCODE -eq 0 -and $BlobSizeText.Count -gt 0) {
            [Int64]$BlobSize = 0
            if ([Int64]::TryParse(([string]$BlobSizeText[0]).Trim(), [ref]$BlobSize)) {
                if ($BlobSize -ge 100MB) { $Oversized += $TrackedPath }
            }
        }
    }
    Write-Host "INDEX BLOBS >=100MB : $($Oversized.Count)"
    if ($Oversized.Count -ne 0) { Hold "GitHub size gate failed" }
    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE / PRESERVATION GATE"
    Fetch-Authoritative
    if ((& git.exe rev-parse ("origin/" + $Branch)).Trim() -ne $ExpectedBaseline) { Hold "Remote advanced during transaction" }
    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) { Hold ("Preservation failure before commit: " + $TrackedPath) }
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "feat(spt-025.11): catalog reusable instance templates and configuration profiles"
    if ($LASTEXITCODE -ne 0) { Hold "git commit failed" }
    Write-Host "NEW COMMIT : $((& git.exe rev-parse HEAD).Trim())"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if ($LASTEXITCODE -ne 0) { Hold "git push failed" }
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

    if ($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0") { Hold "Final synchronization failed" }
    if ($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0) { Hold "Final repository state is not clean enough for closure" }

    Write-Host ""
    Write-Host "SPT-025.11 : TECHNICALLY CLOSED / TEMPLATE & PROFILE CATALOG APPROVED" -ForegroundColor Green
    Write-Host "SPT-025.10_MASTER_REGISTRY_GATE=PASS"
    Write-Host "SPT-025.11_PREPARE_CONSUMED=PASS"
    Write-Host "REPOSITORY_CONTINUITY_GATE=PASS"
    Write-Host "MASTER_TEMPLATE_CATALOG=PASS"
    Write-Host "MASTER_PROFILE_CATALOG=PASS"
    Write-Host "GENERIC_LANGUAGE_NEUTRAL_MODEL=PASS"
    Write-Host "ONE_NATIVE_LANGUAGE_PER_PLATFORM=PASS"
    Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS"
    Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO"
    Write-Host "TEMPLATE_VERSION_GOVERNANCE=PASS"
    Write-Host "PROFILE_VERSION_GOVERNANCE=PASS"
    Write-Host "TEMPLATE_PROFILE_COMPATIBILITY=PASS"
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
    Write-Host "NEXT_DELIVERABLE=SPT-025.12"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
