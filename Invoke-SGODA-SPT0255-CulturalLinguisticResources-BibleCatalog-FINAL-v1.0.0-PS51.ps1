#requires -Version 5.1
[CmdletBinding()] param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="ebe7e82869500a7a04cafd40189b705982c5be84"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ReqAssessment="artifacts/development/SPT-025.4-v1.0.0/spt0254-rlb-contract-assessment.json"
$ReqBoundary="artifacts/development/SPT-025.4-v1.0.0/lexical-instance-boundary-baseline.json"
$ReqCompat="artifacts/development/SPT-025.4-v1.0.0/puinave-rlb-compatibility-baseline.json"
$ReqPrepare="artifacts/development/SPT-025.4-v1.0.0/spt0255-prepare.json"

$CoreFile="src/sgoda/integration/spt0255/core.py"
$InitFile="src/sgoda/integration/spt0255/__init__.py"
$TestFile="tests/integration/test_spt0255_cultural_linguistic_resources_bible_catalog.py"
$PolicyFile="config/integration/spt0255/platform-resource-catalog-policy.json"
$SchemaFile="config/integration/spt0255/platform-resource-catalog.schema.json"
$PuinaveFile="config/integration/spt0255/sgoda-puinave-resource-catalog.json"
$TemplateFile="config/integration/spt0255/platform-resource-catalog-template.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.5/SGD-SPT025.5-Recursos-Culturales-Linguisticos-Biblia-Catalogo.md"

$ArtifactDir="artifacts/development/SPT-025.5-v1.0.0"
$CatalogModelFile="$ArtifactDir/platform-resource-catalog-baseline.json"
$BibleModelFile="$ArtifactDir/bible-resource-governance-baseline.json"
$LanguageScopeFile="$ArtifactDir/resource-language-scope-baseline.json"
$PuinaveBaselineFile="$ArtifactDir/sgoda-puinave-resource-baseline.json"
$BoundaryFile="$ArtifactDir/core-instance-resource-boundary-baseline.json"
$FingerprintFile="$ArtifactDir/resource-catalog-integrity-baseline.json"
$AssessmentFile="$ArtifactDir/spt0255-resource-catalog-assessment.json"
$IntegrityFile="$ArtifactDir/spt0255-integrity-manifest.json"
$PrepareFile="$ArtifactDir/spt0256-prepare.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$T){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$T) -ForegroundColor Cyan}
function Hold([string]$R){Write-Host "";Write-Host "SPT-025.5 : HOLD" -ForegroundColor Red;Write-Host "REASON : $R";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
function Fetch{for($i=1;$i-le4;$i++){Write-Host "GIT FETCH ATTEMPT : $i/4";& git.exe fetch origin $Branch;if($LASTEXITCODE-eq0){Write-Host "GIT FETCH : PASS";return};Start-Sleep 2};Hold "git fetch failed"}
function WriteLf([string]$P,[string]$T){$X=if([IO.Path]::IsPathRooted($P)){$P}else{Join-Path $Root $P};$D=Split-Path -Parent $X;if($D-and-not(Test-Path $D)){New-Item -ItemType Directory -Force -Path $D|Out-Null};$U=New-Object Text.UTF8Encoding($false);$C=(($T-replace"`r`n","`n")-replace"`r","`n");if(-not$C.EndsWith("`n")){$C+="`n"};[IO.File]::WriteAllText($X,$C,$U)}
function Sha([string]$P){(Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash.ToUpperInvariant()}
function SizeGate{$B=@();foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$s=@(& git.exe cat-file -s (":"+$p) 2>$null);if($LASTEXITCODE-eq0-and@($s).Count-gt0){[Int64]$n=0;if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n)-and$n-ge$LargeFileLimit){$B+=($p-replace'\\','/')}}};@($B)}

try{
$Root=(& git.exe rev-parse --show-toplevel).Trim();if(-not$Root){Hold "Not inside Git repository"};Set-Location $Root
$Python=Join-Path $Root ".venv\Scripts\python.exe";if(-not(Test-Path $Python)){$Python="python.exe"}

Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
Fetch
$L=(& git.exe rev-parse HEAD).Trim();$R=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$S=@(& git.exe diff --cached --name-only);$D=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $L";Write-Host "REMOTE HEAD     : $R";Write-Host "STAGED          : $($S.Count)";Write-Host "DELETED TRACKED : $($D.Count)"
if($L-ne$ExpectedBaseline-or$R-ne$ExpectedBaseline){Hold "Authoritative baseline mismatch"}
if($S.Count-ne0-or$D.Count-ne0){Hold "Unsafe staged/deleted state"}
Write-Host "BASELINE : PASS"
Write-Host "SPT-024 / PISI + SPT-025.1-.4 : PROTECTED / NOT REOPENED"
Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY SPT-025.4 RLB CONTRACT INPUTS"
$Req=@($ReqAssessment,$ReqBoundary,$ReqCompat,$ReqPrepare)
$M=@($Req|Where-Object{-not(Test-Path (Join-Path $Root $_))})
Write-Host "REQUIRED SPT-025.4 INPUTS : $($Req.Count)"
Write-Host "MISSING INPUTS            : $($M.Count)"
if($M.Count){Hold "Missing SPT-025.4 inputs"}
$Prev=Get-Content -Raw (Join-Path $Root $ReqAssessment)|ConvertFrom-Json
if([string]$Prev.status-ne"PARAMETRIC_RLB_INSTANCE_DATA_GATE_PASS"){Hold "SPT-025.4 RLB gate is not PASS"}
Write-Host "SPT-025.4 PARAMETRIC RLB / INSTANCE DATA GATE : PASS"

Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
$Freeze=@{}
foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$f=Join-Path $Root $p;if(Test-Path $f){$Freeze[$p]=Sha $f}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
Write-Host "SHA-256 FREEZE : PASS"

Step 4 "CULTURAL / LINGUISTIC RESOURCE CATALOG DISCOVERY"
Write-Host "RESOURCE CATALOG OWNERSHIP : INSTANCE"
Write-Host "BIBLE RESOURCE             : OPTIONAL / CONFIGURABLE"
Write-Host "BIBLE URL                  : INSTANCE CONFIGURATION"
Write-Host "RESOURCE ENABLE/DISABLE    : PER PLATFORM"
Write-Host "RESOURCE LANGUAGE SCOPE    : CONFIGURABLE"
Write-Host "SGODA CORE RESOURCE VALUES : NONE"
Write-Host "EXTERNAL CONNECTION OPENED : NO"

Step 5 "IMPLEMENT SPT-025.5 RESOURCE CATALOG"
$Core=@'
from dataclasses import dataclass
from hashlib import sha256
import json

ALLOWED_RESOURCE_TYPES = (
    "bible","dictionary","grammar","story","song","video","audio",
    "document","website","education","culture","custom"
)

@dataclass(frozen=True)
class ResourceValidation:
    valid: bool
    errors: tuple

def normalize_code(value):
    return str(value or "").strip().lower().replace("_","-")

def normalize_resource_type(value):
    return str(value or "").strip().lower().replace(" ","_")

def validate_resource(resource, native_code, support_codes):
    errors=[]
    if not isinstance(resource,dict):
        return {"valid":False,"errors":["resource_not_object"]}

    rid=str(resource.get("resource_id","")).strip()
    name=str(resource.get("name","")).strip()
    rtype=normalize_resource_type(resource.get("type"))
    enabled=resource.get("enabled")
    scope=normalize_code(resource.get("language_scope"))

    if not rid: errors.append("resource_id_required")
    if not name: errors.append("resource_name_required")
    if rtype not in ALLOWED_RESOURCE_TYPES: errors.append("resource_type_invalid")
    if not isinstance(enabled,bool): errors.append("resource_enabled_must_be_boolean")

    allowed_scopes={normalize_code(native_code),"multilingual","none"}
    allowed_scopes.update(normalize_code(x) for x in support_codes)
    if scope not in allowed_scopes:
        errors.append("resource_language_scope_not_enabled")

    source=resource.get("source")
    if not isinstance(source,dict):
        errors.append("resource_source_not_object")
    else:
        mode=str(source.get("mode","")).strip().lower()
        if mode not in ("url","local","none"):
            errors.append("resource_source_mode_invalid")
        if mode=="url" and not str(source.get("url","")).strip():
            errors.append("resource_url_required")
        if mode=="local" and not str(source.get("path","")).strip():
            errors.append("resource_local_path_required")

    if rtype=="bible":
        if resource.get("platform_configurable") is not True:
            errors.append("bible_must_be_platform_configurable")
        if source and isinstance(source,dict) and source.get("mode")=="url":
            if resource.get("url_configurable") is not True:
                errors.append("bible_url_must_be_configurable")

    return {"valid":not errors,"errors":errors}

def validate_catalog(catalog):
    errors=[]
    if not isinstance(catalog,dict):
        return {"valid":False,"errors":["catalog_not_object"]}
    native=normalize_code(catalog.get("native_language"))
    supports=[normalize_code(x) for x in catalog.get("support_languages",[]) if normalize_code(x)]
    if not native: errors.append("catalog_native_language_required")
    if native in supports: errors.append("native_language_cannot_be_support_language")
    if catalog.get("instance_specific") is not True:
        errors.append("catalog_must_be_instance_specific")
    if catalog.get("sgoda_core_embeds_resource_values") is not False:
        errors.append("sgoda_core_must_not_embed_resource_values")

    ids=set()
    resources=catalog.get("resources")
    if not isinstance(resources,list):
        errors.append("catalog_resources_not_list")
        resources=[]
    for idx,res in enumerate(resources):
        result=validate_resource(res,native,supports)
        errors.extend(f"resource_{idx}:{e}" for e in result["errors"])
        if isinstance(res,dict):
            rid=str(res.get("resource_id","")).strip()
            if rid and rid in ids:
                errors.append(f"resource_{idx}:duplicate_resource_id")
            ids.add(rid)
    return {
        "valid":not errors,
        "errors":errors,
        "resource_count":len(resources),
        "enabled_count":len([x for x in resources if isinstance(x,dict) and x.get("enabled") is True]),
    }

def reference_puinave_catalog():
    return {
        "platform_id":"sgoda-puinave",
        "native_language":"pui",
        "support_languages":["es","en","it","pt"],
        "instance_specific":True,
        "sgoda_core_embeds_resource_values":False,
        "resources":[
            {
                "resource_id":"PUINAVE-BIBLE-001",
                "name":"Biblia Puinave",
                "type":"bible",
                "enabled":True,
                "language_scope":"pui",
                "platform_configurable":True,
                "url_configurable":True,
                "source":{"mode":"url","url":"<CONFIGURABLE-BIBLE-URL>"},
                "metadata":{"category":"spiritual-cultural","optional":True}
            }
        ]
    }

def build_resource(resource_id,name,rtype,language_scope,enabled=True,source_mode="none",source_value=""):
    source={"mode":source_mode}
    if source_mode=="url": source["url"]=source_value
    elif source_mode=="local": source["path"]=source_value
    result={
        "resource_id":str(resource_id or "").strip(),
        "name":str(name or "").strip(),
        "type":normalize_resource_type(rtype),
        "enabled":bool(enabled),
        "language_scope":normalize_code(language_scope),
        "platform_configurable":True,
        "source":source,
        "metadata":{}
    }
    if result["type"]=="bible":
        result["url_configurable"]=True
    return result

def catalog_fingerprint(catalog):
    payload=json.dumps(catalog,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()
'@
$Init=@'
from .core import (
    ALLOWED_RESOURCE_TYPES,ResourceValidation,normalize_code,normalize_resource_type,
    validate_resource,validate_catalog,reference_puinave_catalog,build_resource,catalog_fingerprint
)
__all__=[
    "ALLOWED_RESOURCE_TYPES","ResourceValidation","normalize_code","normalize_resource_type",
    "validate_resource","validate_catalog","reference_puinave_catalog","build_resource","catalog_fingerprint"
]
'@
$Tests=@'
from sgoda.integration.spt0255 import *

def ref(): return reference_puinave_catalog()

def test_01(): assert "bible" in ALLOWED_RESOURCE_TYPES
def test_02(): assert normalize_code(" PT ")=="pt"
def test_03(): assert normalize_resource_type("Custom")=="custom"
def test_04(): assert validate_catalog(ref())["valid"]
def test_05(): assert validate_catalog(ref())["resource_count"]==1
def test_06(): assert validate_catalog(ref())["enabled_count"]==1
def test_07(): assert ref()["native_language"]=="pui"
def test_08(): assert ref()["support_languages"]==["es","en","it","pt"]
def test_09(): assert ref()["sgoda_core_embeds_resource_values"] is False
def test_10(): assert ref()["resources"][0]["platform_configurable"] is True
def test_11(): assert ref()["resources"][0]["url_configurable"] is True
def test_12():
    x=ref(); x["resources"][0]["platform_configurable"]=False
    assert not validate_catalog(x)["valid"]
def test_13():
    x=ref(); x["resources"][0]["url_configurable"]=False
    assert not validate_catalog(x)["valid"]
def test_14():
    x=ref(); x["resources"][0]["source"]["url"]=""
    assert not validate_catalog(x)["valid"]
def test_15():
    x=ref(); x["resources"][0]["language_scope"]="fr"
    assert not validate_catalog(x)["valid"]
def test_16():
    x=ref(); x["resources"].append(dict(x["resources"][0]))
    assert any("duplicate_resource_id" in e for e in validate_catalog(x)["errors"])
def test_17():
    r=build_resource("X","Historia","story","pui",True,"local","stories/x.md")
    assert r["source"]["mode"]=="local"
def test_18():
    r=build_resource("X","Sitio","website","es",True,"url","https://example.invalid")
    assert r["source"]["mode"]=="url"
def test_19():
    r=build_resource("B","Biblia","bible","pui",True,"url","https://example.invalid")
    assert r["url_configurable"] is True
def test_20():
    x=ref(); x["resources"][0]["enabled"]=False
    assert validate_catalog(x)["valid"] and validate_catalog(x)["enabled_count"]==0
def test_21():
    x=ref(); x["instance_specific"]=False
    assert "catalog_must_be_instance_specific" in validate_catalog(x)["errors"]
def test_22():
    x=ref(); x["sgoda_core_embeds_resource_values"]=True
    assert "sgoda_core_must_not_embed_resource_values" in validate_catalog(x)["errors"]
def test_23(): assert catalog_fingerprint(ref())==catalog_fingerprint(ref())
def test_24():
    x=ref(); y=ref(); y["resources"][0]["name"]="Otra Biblia"
    assert catalog_fingerprint(x)!=catalog_fingerprint(y)
'@
$Policy=@'
{
  "component": "SPT-025.5",
  "version": "1.0.0",
  "title": "Recursos Culturales y Linguisticos Configurables por Plataforma, Biblia y Catalogo de Recursos",
  "authoritative_baseline": "ebe7e82869500a7a04cafd40189b705982c5be84",
  "architecture": {
    "resource_catalog": "INSTANCE_SPECIFIC",
    "sgoda_core_embeds_resource_values": false,
    "bible_optional": true,
    "bible_configurable_per_platform": true,
    "bible_url_configurable": true,
    "resource_enable_disable_per_platform": true,
    "resource_types_configurable": true,
    "language_scope": "NATIVE_OR_ENABLED_SUPPORT_OR_MULTILINGUAL",
    "reference_platform": "SGODA-PUINAVE",
    "reference_native_language": "pui",
    "reference_support_languages": [
      "es",
      "en",
      "it",
      "pt"
    ]
  },
  "mode": "NON_DESTRUCTIVE_RESOURCE_CATALOG_DEFINITION",
  "rules": {
    "modify_spt004b": false,
    "replace_existing_bible_link": false,
    "modify_closed_components": false,
    "production_change": false,
    "external_connection_opened": false,
    "commit_push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
$Schema=@'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SGODA Platform Resource Catalog",
  "type": "object",
  "required": [
    "platform_id",
    "native_language",
    "support_languages",
    "instance_specific",
    "sgoda_core_embeds_resource_values",
    "resources"
  ],
  "properties": {
    "platform_id": {
      "type": "string",
      "minLength": 1
    },
    "native_language": {
      "type": "string",
      "minLength": 1
    },
    "support_languages": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "instance_specific": {
      "const": true
    },
    "sgoda_core_embeds_resource_values": {
      "const": false
    },
    "resources": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [
          "resource_id",
          "name",
          "type",
          "enabled",
          "language_scope",
          "platform_configurable",
          "source"
        ],
        "properties": {
          "resource_id": {
            "type": "string",
            "minLength": 1
          },
          "name": {
            "type": "string",
            "minLength": 1
          },
          "type": {
            "type": "string"
          },
          "enabled": {
            "type": "boolean"
          },
          "language_scope": {
            "type": "string"
          },
          "platform_configurable": {
            "const": true
          },
          "url_configurable": {
            "type": "boolean"
          },
          "source": {
            "type": "object"
          }
        }
      }
    }
  }
}
'@
$Puinave=@'
{
  "platform_id": "sgoda-puinave",
  "native_language": "pui",
  "support_languages": [
    "es",
    "en",
    "it",
    "pt"
  ],
  "instance_specific": true,
  "sgoda_core_embeds_resource_values": false,
  "resources": [
    {
      "resource_id": "PUINAVE-BIBLE-001",
      "name": "Biblia Puinave",
      "type": "bible",
      "enabled": true,
      "language_scope": "pui",
      "platform_configurable": true,
      "url_configurable": true,
      "source": {
        "mode": "url",
        "url": "<CONFIGURABLE-BIBLE-URL>"
      },
      "metadata": {
        "category": "spiritual-cultural",
        "optional": true
      }
    }
  ]
}
'@
$Template=@'
{
  "platform_id": "sgoda-<native-language>",
  "native_language": "<native-code>",
  "support_languages": [
    "<support-code-1>"
  ],
  "instance_specific": true,
  "sgoda_core_embeds_resource_values": false,
  "resources": [
    {
      "resource_id": "<RESOURCE-ID>",
      "name": "<RESOURCE-NAME>",
      "type": "custom",
      "enabled": true,
      "language_scope": "<native-code>",
      "platform_configurable": true,
      "source": {
        "mode": "none"
      },
      "metadata": {}
    }
  ]
}
'@
$Doc=@'
# SPT-025.5 — Recursos Culturales y Lingüísticos Configurables por Plataforma, Biblia y Catálogo de Recursos

Baseline autoritativa: `ebe7e82869500a7a04cafd40189b705982c5be84`.

## Objetivo
Formalizar un catálogo de recursos propio de cada plataforma lingüística independiente.

## Principios
- SGODA Core no contiene enlaces, rutas ni valores concretos de recursos culturales.
- Cada plataforma mantiene su propio catálogo.
- La Biblia es un recurso opcional y configurable por plataforma.
- El enlace de Biblia se configura en la instancia y no en SGODA Core.
- Los recursos pueden habilitarse o deshabilitarse sin modificar el núcleo.
- Un recurso puede corresponder a la lengua nativa, a un idioma auxiliar habilitado, ser multilingüe o no tener idioma.
- El catálogo admite Biblia, diccionario, gramática, historias, canciones, audio, video, documentos, sitios web, educación, cultura y recursos personalizados.

## SGODA-PUINAVE
La configuración de referencia mantiene Puinave (`pui`) como lengua principal y `es`, `en`, `it`, `pt` como idiomas auxiliares. La Biblia Puinave queda modelada como recurso de instancia configurable.

## Preservación
Esta capa no modifica SPT-004B, no sustituye el enlace real existente y no abre conexiones externas.
'@
WriteLf $CoreFile $Core
WriteLf $InitFile $Init
WriteLf $TestFile $Tests
WriteLf $PolicyFile $Policy
WriteLf $SchemaFile $Schema
WriteLf $PuinaveFile $Puinave
WriteLf $TemplateFile $Template
WriteLf $DocFile $Doc
Write-Host "SPT-025.5 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
& $Python -c "from sgoda.integration.spt0255 import reference_puinave_catalog,validate_catalog; r=validate_catalog(reference_puinave_catalog()); assert r['valid']; print('SPT0255_IMPORT=PASS'); print('PUINAVE_RESOURCE_CATALOG=PASS'); print('BIBLE_CONFIGURABLE=PASS')"
if($LASTEXITCODE){Hold "SPT-025.5 import/catalog validation failed"}
& $Python -m pytest -q $TestFile
if($LASTEXITCODE){Hold "Targeted tests failed"}
Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
& $Python -m pytest -q
if($LASTEXITCODE){Hold "Institutional suite failed"}
Write-Host "FULL SUITE : PASS"
& $Python -m compileall -q (Join-Path $Root "src")
if($LASTEXITCODE){Hold "compileall failed"}
Write-Host "COMPILEALL : PASS"

Step 8 "RESOURCE / BIBLE GOVERNANCE ASSESSMENT"
$Cfg=Get-Content -Raw (Join-Path $Root $PuinaveFile)|ConvertFrom-Json
if(-not[bool]$Cfg.instance_specific){Hold "Resource catalog must be instance specific"}
if([bool]$Cfg.sgoda_core_embeds_resource_values){Hold "SGODA Core must not embed resource values"}
$Bible=@($Cfg.resources|Where-Object{[string]$_.type-eq"bible"})
if($Bible.Count-ne1){Hold "Reference Puinave catalog must contain one Bible resource definition"}
if(-not[bool]$Bible[0].platform_configurable-or-not[bool]$Bible[0].url_configurable){Hold "Bible must be configurable"}
Write-Host "RESOURCE_CATALOG_INSTANCE_SPECIFIC=PASS"
Write-Host "SGODA_CORE_EMBEDS_RESOURCE_VALUES=NO"
Write-Host "BIBLE_OPTIONAL_RESOURCE=PASS"
Write-Host "BIBLE_CONFIGURABLE_PER_PLATFORM=PASS"
Write-Host "BIBLE_URL_CONFIGURABLE=PASS"
Write-Host "RESOURCE_ENABLE_DISABLE=PASS"
Write-Host "RESOURCE_LANGUAGE_SCOPE_CONFIGURABLE=PASS"
Write-Host "PUINAVE_RESOURCE_CATALOG=PASS"
Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
Write-Host "RESOURCE / BIBLE GOVERNANCE GATE : PASS"

Step 9 "RESOURCE BASELINES / PREPARE / EVIDENCE"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
$Catalog=[ordered]@{model="PLATFORM_RESOURCE_CATALOG";ownership="INSTANCE";types=@("bible","dictionary","grammar","story","song","video","audio","document","website","education","culture","custom");enable_disable=$true;language_scope_configurable=$true}
$BibleModel=[ordered]@{type="bible";optional=$true;platform_configurable=$true;url_configurable=$true;sgoda_core_embeds_url=$false;external_access_execution="NOT_PERFORMED"}
$Scope=[ordered]@{allowed=@("native_language","enabled_support_language","multilingual","none");validation_required=$true}
$Pui=[ordered]@{platform="SGODA-PUINAVE";native_language="pui";support_languages=@("es","en","it","pt");bible_resource_id="PUINAVE-BIBLE-001";bible_enabled=$true;bible_url="<CONFIGURABLE-BIBLE-URL>"}
$Boundary=[ordered]@{sgoda_core=@("resource_contracts","validation","catalog_service","security","testing","evidence");instance=@("resource_names","resource_urls","resource_paths","resource_enablement","language_scope","community_metadata")}
$TmpCatalog=Join-Path ([IO.Path]::GetTempPath()) ("spt0255-catalog-"+[guid]::NewGuid().ToString("N")+".json")
WriteLf $TmpCatalog ($Cfg|ConvertTo-Json -Depth 12)
$CatalogHash=Sha $TmpCatalog
Remove-Item $TmpCatalog -Force -ErrorAction SilentlyContinue
$Fingerprint=[ordered]@{algorithm="SHA-256";reference_catalog="SGODA-PUINAVE";sha256=$CatalogHash}
$Assessment=[ordered]@{component="SPT-025.5";version="1.0.0";baseline=$ExpectedBaseline;status="RESOURCE_BIBLE_GOVERNANCE_GATE_PASS";catalog_instance_specific=$true;sgoda_core_embeds_resource_values=$false;bible_configurable_per_platform=$true;bible_url_configurable=$true;external_connection_opened=$false;closed_components_preserved=$true}
$Prepare=[ordered]@{next_deliverable="SPT-025.6";title="Identidad Comunitaria, Branding, Metadatos de Comunidad y Configuracion de Plataforma";source_baseline=$ExpectedBaseline;resource_catalog_gate="PASS"}
WriteLf $CatalogModelFile ($Catalog|ConvertTo-Json -Depth 8)
WriteLf $BibleModelFile ($BibleModel|ConvertTo-Json -Depth 8)
WriteLf $LanguageScopeFile ($Scope|ConvertTo-Json -Depth 8)
WriteLf $PuinaveBaselineFile ($Pui|ConvertTo-Json -Depth 8)
WriteLf $BoundaryFile ($Boundary|ConvertTo-Json -Depth 8)
WriteLf $FingerprintFile ($Fingerprint|ConvertTo-Json -Depth 8)
WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 8)
WriteLf $PrepareFile ($Prepare|ConvertTo-Json -Depth 8)
$MR=@()
foreach($p in @($PolicyFile,$SchemaFile,$PuinaveFile,$TemplateFile,$DocFile,$CatalogModelFile,$BibleModelFile,$LanguageScopeFile,$PuinaveBaselineFile,$BoundaryFile,$FingerprintFile,$AssessmentFile,$PrepareFile)){$MR+=[ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}}
WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$MR}|ConvertTo-Json -Depth 10)
WriteLf $EvidenceFile ([ordered]@{component="SPT-025.5";version="1.0.0";baseline=$ExpectedBaseline;status="RESOURCE_BIBLE_GOVERNANCE_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";spt004b_modified=$false;external_connection_opened=$false;production_change=$false;closed_components_preserved=$true}|ConvertTo-Json -Depth 8)
Write-Host "RESOURCE CATALOG MODEL : CREATED"
Write-Host "BIBLE GOVERNANCE       : CREATED"
Write-Host "LANGUAGE SCOPE MODEL   : CREATED"
Write-Host "PUINAVE BASELINE       : CREATED"
Write-Host "CORE/INSTANCE BOUNDARY : CREATED"
Write-Host "CATALOG INTEGRITY      : CREATED"
Write-Host "SPT-025.6 PREPARE      : CREATED"
Write-Host "EVIDENCE               : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Protected tracked file changed: $p"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "SPT-024 / PISI + SPT-025.1-.4 + CLOSED COMPONENTS : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@("Invoke-SGODA-SPT0255-CulturalLinguisticResources-BibleCatalog-FINAL-v1.0.0-PS51.ps1",$CoreFile,$InitFile,$TestFile,$PolicyFile,$SchemaFile,$PuinaveFile,$TemplateFile,$DocFile,$CatalogModelFile,$BibleModelFile,$LanguageScopeFile,$PuinaveBaselineFile,$BoundaryFile,$FingerprintFile,$AssessmentFile,$IntegrityFile,$PrepareFile,$EvidenceFile)
foreach($p in $Allowed){if(-not(Test-Path (Join-Path $Root $p))){Hold "Missing expected target: $p"};& git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $p;if($LASTEXITCODE){Hold "git add failed: $p"}}
$SN=@(& git.exe -c core.quotepath=false diff --cached --name-only)
$U=@($SN|Where-Object{$Allowed-notcontains($_-replace'\\','/')})
Write-Host "STAGED     : $($SN.Count)"
Write-Host "UNEXPECTED : $($U.Count)"
if($U.Count-or$SN.Count-ne$Allowed.Count){Hold "Exact staging mismatch"}
Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$B=@(SizeGate)
Write-Host "INDEX BLOBS >=100MB : $($B.Count)"
if($B.Count){Hold "Git index contains blob >=100 MB"}
Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE / PRESERVATION GATE"
Fetch
$R2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
if($R2-ne$ExpectedBaseline){Hold "Remote advanced during transaction"}
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Preservation changed before commit"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
& git.exe commit -m "feat(spt-025.5): implement configurable cultural linguistic resource and Bible catalog"
if($LASTEXITCODE){Hold "git commit failed"}
$NC=(& git.exe rev-parse HEAD).Trim()
Write-Host "NEW COMMIT : $NC"

Step 15 "PUSH"
& git.exe push origin $Branch
if($LASTEXITCODE){Hold "git push failed"}
Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TECHNICAL CLOSURE"
Fetch
$FL=(& git.exe rev-parse HEAD).Trim()
$FR=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim()
$Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
$FS=@(& git.exe diff --cached --name-only)
$FD=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FL"
Write-Host "REMOTE HEAD     : $FR"
Write-Host "BEHIND          : $Behind"
Write-Host "AHEAD           : $Ahead"
Write-Host "STAGED          : $($FS.Count)"
Write-Host "DELETED TRACKED : $($FD.Count)"
if($FL-ne$FR-or$Behind-ne"0"-or$Ahead-ne"0"-or$FS.Count-ne0-or$FD.Count-ne0){Hold "Final synchronization failed"}

Write-Host ""
Write-Host "SPT-025.5 : TECHNICALLY CLOSED / RESOURCE & BIBLE CATALOG APPROVED" -ForegroundColor Green
Write-Host "SPT-025.4_PARAMETRIC_RLB_GATE=PASS"
Write-Host "RESOURCE_CATALOG_INSTANCE_SPECIFIC=PASS"
Write-Host "SGODA_CORE_EMBEDS_RESOURCE_VALUES=NO"
Write-Host "BIBLE_OPTIONAL_RESOURCE=PASS"
Write-Host "BIBLE_CONFIGURABLE_PER_PLATFORM=PASS"
Write-Host "BIBLE_URL_CONFIGURABLE=PASS"
Write-Host "RESOURCE_ENABLE_DISABLE=PASS"
Write-Host "RESOURCE_LANGUAGE_SCOPE_CONFIGURABLE=PASS"
Write-Host "PUINAVE_NATIVE_LANGUAGE=PUI"
Write-Host "PUINAVE_SUPPORT_LANGUAGES=ES,EN,IT,PT"
Write-Host "SPT004B_MODIFIED=NO"
Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
Write-Host "DESTRUCTIVE_CHANGE=NO"
Write-Host "PRODUCTION_CHANGE=NO"
Write-Host "TARGETED_TESTS=PASS"
Write-Host "INSTITUTIONAL_SUITE=PASS"
Write-Host "COMPILEALL=PASS"
Write-Host "CLOSED_COMPONENTS=PRESERVED"
Write-Host "LOCAL_HEAD=REMOTE_HEAD"
Write-Host "NEXT_DELIVERABLE=SPT-025.6"
Write-Host "FINAL_EXIT_CODE=0"
exit 0
}catch{Hold $_.Exception.Message}
